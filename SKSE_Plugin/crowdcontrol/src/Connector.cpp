#include "Connector.h"

#include <ws2tcpip.h>
#include <stdio.h>
#include <iostream>
#include <functional>
#include <chrono>
#include <memory>

#include "rapidjson/document.h"
#include "rapidjson/stringbuffer.h"
#include "rapidjson/writer.h"
#include "skse64/PapyrusModEvent.h"
#include "skse64/PapyrusEvents.h"
#include "skse64/GameUtilities.h"
#include "skse64/gamethreads.h"  // TaskDelegate
#include "skse64/GameAPI.h"
#pragma comment(lib, "Ws2_32.lib")


Connector::Connector()
{
	WORD wVersionRequested = MAKEWORD(2, 2);
	WSADATA wsaData = { 0 };
	int err = WSAStartup(wVersionRequested, &wsaData);
}

Connector::~Connector()
{
	if (m_socket != INVALID_SOCKET)
	{
		closesocket(m_socket);
		m_socket = INVALID_SOCKET;
	}

	WSACleanup();
}

bool Connector::HasError()
{
	return hasError;
}

const char* Connector::GetError()
{
	return (const char*)error;
}

void Connector::ResetError()
{
	hasError = false;
	ZeroMemory(&error, sizeof(error));
}

bool Connector::IsConnected()
{
	return m_socket != INVALID_SOCKET && !connecting;
}

bool Connector::IsRunning()
{
	return running && checking;
}

void Connector::OnMenu(bool isOpen)
{
	std::lock_guard guard(m_mutex);
	menuOpened = isOpen;
}

int Connector::GetItemCount()
{
	std::lock_guard guard(m_mutex);
	return command_map.size();
}

std::shared_ptr<Command> Connector::PopItem()
{
	try
	{
		std::lock_guard guard(m_mutex);
		if (command_map.size() > 0)
		{
			auto iter = command_map.begin();
			auto last = iter->second;
			//command_map.erase(iter);
			return last;
		}
	}
	catch (std::exception e)
	{
		_ERROR("[Connector::Connect] %s", e.what());
	}

	return NULL;
}

void Connector::NewTimer(UINT command_id, int miliseconds)
{
	std::lock_guard guard(m_mutex);
	auto c = command_map[command_id];
	c->type = 2;
	c->time = GetElapsedTime() + (long long)miliseconds;
	//_MESSAGE("Time: %d + %d = %d", GetElapsedTime(), (long long)miliseconds, GetElapsedTime() + (long long)miliseconds);
	timer_map.insert({ c->command, c });
}

void Connector::ExtendTimer(UINT command_id, int miliseconds)
{
	std::lock_guard guard(m_mutex);
	auto c = command_map[command_id];
	c->time += miliseconds;
}

bool Connector::HasTimer(UINT command_id)
{
	try
	{
		std::lock_guard guard(m_mutex);
		auto c = command_map[command_id];
		return HasTimer(c->command);
	}
	catch (std::exception e)
	{
		_ERROR("[Connector::HasTimer] %s", e.what());
	}

	return false;
}

bool Connector::HasTimer(std::string command_name)
{
	return timer_map.find(command_name) != timer_map.end();
}

void Connector::ClearTimers()
{
	std::lock_guard lock(m_mutex);
	timer_map.clear();
}

void Connector::ConnectAsync(const char* port)
{
	if (IsConnected()) return;
	if (connect_thread.valid())
	{
		auto status = connect_thread.wait_for(std::chrono::milliseconds::zero());
		if (status == std::future_status::ready)
		{
			bool result = connect_thread.get();

			if (!result)
				connect_thread = std::async(&Connector::Connect, this, port);

			else
				connect_thread = std::future<bool>();
		}
	}
	else
	{
		connect_thread = std::async(&Connector::Connect, this, port);
	}
}

bool Connector::Connect(const char* port)
{
	value_lock connect_lock(&connecting, true, false);

	try
	{
		int iFamily = AF_INET;
		int iType = SOCK_STREAM;
		int iProtocol = IPPROTO_TCP;

		struct addrinfo* result = NULL,
			* ptr = NULL,
			hints;

		ZeroMemory(&hints, sizeof(hints));

		iResult = getaddrinfo("127.0.0.1", port, &hints, &result);

		if (iResult != 0)
		{
			hasError = true;
			snprintf(error, sizeof(error), "getaddrinfo error: %d", iResult);

			return false;
		}

		ptr = result;

		m_socket = socket(ptr->ai_family, ptr->ai_socktype, ptr->ai_protocol);

		if (m_socket == INVALID_SOCKET)
		{
			hasError = true;
			snprintf(error, sizeof(error), "Socket creation failed: %d", WSAGetLastError());

			return false;
		}

		iResult = connect(m_socket, ptr->ai_addr, (int)ptr->ai_addrlen);
		if (iResult == SOCKET_ERROR)
		{
			hasError = true;
			//closesocket(m_socket);

			m_socket = INVALID_SOCKET;
			snprintf(error, sizeof(error), "Error connecting to Crowd Control");

			return false;
		}

		ResetError();
		connecting = false;
		Run();

		return true;
	}
	catch (std::exception e)
	{
		_ERROR("[Connector::Connect] %s", e.what());
		if (m_socket != INVALID_SOCKET)
		{
			closesocket(m_socket);
			m_socket = INVALID_SOCKET;
		}
	}

	return false;
}

void Connector::Respond(SInt32 id, SInt32 status, BSFixedString message, int miliseconds)
{
	try
	{
		std::shared_ptr<Command> c;
		{
			std::lock_guard lock(m_mutex);
			auto iter = command_map.find((UINT)id);
			if (iter == command_map.end())
				return;
			c = iter->second;
		}

		bool timer_created = false;
		if (status == 4)
		{
			timer_created = true;
			status = 0;
			if (!HasTimer(id))
			{
				NewTimer(id, miliseconds);
			}
			else
			{
				_MESSAGE("Extending timer for %s", c->command.c_str());
				ExtendTimer(id, miliseconds);
			}
		}

		if (c->type == 1 || timer_created)
			Respond(id, status, message);

		std::lock_guard lock(m_mutex);
		command_map.erase(c->id);
	}
	catch (std::exception e)
	{
		_ERROR("[Connector::Respond] %s", e.what());
	}
}

void Connector::Respond(SInt32 id, SInt32 status, BSFixedString message)
{
	try
	{
		rapidjson::Document data;
		data.SetObject();

		rapidjson::Document::AllocatorType& allocator = data.GetAllocator();
		size_t sz = allocator.Size();

		data.AddMember("id", id, allocator);
		data.AddMember("status", status, allocator);

		rapidjson::Value val(rapidjson::kStringType);

		if (strlen(message.c_str()) > 0)
		{
			val.SetString(message.c_str(), static_cast<rapidjson::SizeType>(strlen(message.c_str())), allocator);
			data.AddMember("message", val, allocator);
		}

		rapidjson::StringBuffer buf;
		rapidjson::Writer<rapidjson::StringBuffer> writer(buf);

		data.Accept(writer);
		buf.Put('\0');

		send(m_socket, buf.GetString(), buf.GetLength(), 0);
	}
	catch (std::exception e)
	{
		_ERROR("[Connector::Respond 2] %s", e.what());
	}
}

void Connector::Run()
{
	if (!IsConnected()) return;
	if (run_thread.valid())
	{
		auto status = run_thread.wait_for(std::chrono::milliseconds::zero());

		if (status == std::future_status::ready)
		{
			run_thread = std::async(&Connector::_Run, this);
		}
	}
	else
	{
		run_thread = std::async(&Connector::_Run, this);
	}

	if (command_check_thread.valid())
	{
		auto status = command_check_thread.wait_for(std::chrono::milliseconds::zero());

		if (status == std::future_status::ready)
		{
			command_check_thread = std::async(&Connector::_RunTimer, this);
		}
	}
	else
	{
		command_check_thread = std::async(&Connector::_RunTimer, this);
	}
}

long long Connector::GetElapsedTime()
{
	return GetElapsedTime(start_time);
}

long long Connector::GetElapsedTime(std::chrono::steady_clock::time_point time)
{
	return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - time).count();
}

void Connector::_RunTimer()
{
	value_lock check_lock(&checking, true, false);
	while (true)
	{
		Sleep(500);
		try
		{
			std::lock_guard guard(m_mutex);

			long long delta_time = 0;
			if (menuOpened)
			{
				delta_time = GetElapsedTime(last_update);
			}

			long long cur_timer = GetElapsedTime();

			auto iter = command_map.begin();
			while (iter != command_map.end())
			{
				if (iter->second->type == 1 && cur_timer - iter->second->time > 2000)
				{
					Respond((int)iter->first, (int)3, "");
					iter = command_map.erase(iter);
				}
				else iter++;
			}

			auto timer_iter = timer_map.begin();
			while (timer_iter != timer_map.end())
			{
				timer_iter->second->time += delta_time;
				auto c = timer_iter->second;
				if (cur_timer > c->time)
				{
					command_map.insert({ c->id, c });
					timer_iter = timer_map.erase(timer_iter);
				}
				else timer_iter++;
			}

			last_update = std::chrono::steady_clock::now();
		}
		catch (std::exception e)
		{
			_ERROR("[Connector::_RunTimer] %s", e.what());
		}
	}
}

void Connector::_Run()
{
	value_lock run_lock(&running, true, false);
	while (true)
	{
		try
		{
			ResetError();
			int last_error = 0;
			int recvbuflen = DEFAULT_BUFLEN;
			char recvbuf[DEFAULT_BUFLEN];
			ZeroMemory(&recvbuf, sizeof(recvbuf));

			iResult = recv(m_socket, recvbuf, recvbuflen, 0);
			if (iResult > 0)
			{

				// EXAMPLE: {"id":1,"code":"spawn_dragon","viewer":"sdk","type":1}\0

				auto commands = BufferSocketResponse(recvbuf, iResult);

				for (auto c : commands)
				{
					if (c.length() == 0) continue;
					//_MESSAGE("Command: %s", c);

					rapidjson::Document data;
					data.Parse(c.c_str());
					if (data.IsObject())
					{
						UINT command_id = data["id"].GetUint();
						std::string command_code = data["code"].GetString();
						std::string command_viewer = data["viewer"].GetString();
						int command_type = data["type"].GetInt();

						std::lock_guard<std::mutex> lock(m_mutex);
						command_map.insert({ command_id,
							std::make_shared<Command>(Command{
								command_id,
								command_code,
								command_viewer,
								command_type,
								GetElapsedTime()
							}) });
					}
				}
			}

			else if (iResult == 0)
			{
				hasError = true;
				snprintf(error, sizeof(error), "Connection closed");
				m_socket = INVALID_SOCKET;
				break;
			}

			else
			{
				last_error = WSAGetLastError();
				if (last_error != (int)WSAEWOULDBLOCK)
				{
					hasError = true;
					snprintf(error, sizeof(error), "recv failed: %d\n", last_error);
					m_socket = INVALID_SOCKET;
					break;
				}
			}
		}
		catch (std::exception e)
		{
			_ERROR("[Connector::_Run] %s", e.what());
		}
	}
}

std::vector<std::string> Connector::BufferSocketResponse(const char* buf, size_t buf_size)
{
	socketBuffer.append(buf, buf_size);
	std::vector<std::string> buffer_array;

	size_t index = socketBuffer.find('\0');
	while (index != std::string::npos)
	{
		buffer_array.push_back(socketBuffer.substr(0, index));
		socketBuffer = socketBuffer.substr(index+1);
		index = socketBuffer.find('\0');
	}

	return buffer_array;
}