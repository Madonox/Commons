"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[557],{42904:e=>{e.exports=JSON.parse('{"functions":[{"name":"_init","desc":"This function handles NettyClient initialization.  Since both the Server and Client modules exist under ReplicatedStorage, we use this function to prevent the server from constructing a client as well.","params":[],"returns":[],"function_type":"static","private":true,"source":{"line":51,"path":"src/Commons/Netty/NettyClient.luau"}},{"name":"Start","desc":"This function starts the network inbound and outbound handler.  Additionally, once NettyClient is started, you can begin to send and receive data to and from the server.","params":[],"returns":[],"function_type":"static","source":{"line":170,"path":"src/Commons/Netty/NettyClient.luau"}},{"name":"_startNetworkRelay","desc":"This function spawns the Netty outbound network connection.","params":[],"returns":[],"function_type":"static","private":true,"source":{"line":203,"path":"src/Commons/Netty/NettyClient.luau"}},{"name":"RegisterEvent","desc":"This function registers an event locally.  This is used when the server wants to send data to the client.  Events can only have **one** callback.\\n\\n:::info\\nEvents also need to be registered on the server, even if they have no callback.  Since Netty uses an identity based system, the client and server need to share event ids.","params":[{"name":"id","desc":"The event id to bind to.","lua_type":"any"},{"name":"callback","desc":"The callback function to run when this event is triggered.","lua_type":"(...any) -> nil"}],"returns":[],"function_type":"static","source":{"line":230,"path":"src/Commons/Netty/NettyClient.luau"}},{"name":"SpawnEvent","desc":"This function spawns an event in the current thread.\\n\\n:::note\\nThis function is mainly used internally, so it doesn\'t offer much configuration / outside influence.","params":[{"name":"eventType","desc":"The event id to trigger.","lua_type":"any"},{"name":"...","desc":"The arguments to pass to the event.","lua_type":"any"}],"returns":[],"function_type":"static","source":{"line":243,"path":"src/Commons/Netty/NettyClient.luau"}},{"name":"FireServer","desc":"This function fires a reliable remote event with proper data serialization to the server.\\n\\n:::note\\nEvents aren\'t fire instantly.  They\'re queued into an outbound pool, and a maximum of 255 events of each type(unreliable, reliable) are fired to the server at once per Heartbeat (RunService.Heartbeat).\\nThis function supports all data types, even if they aren\'t able to be serialized into buffers.\\nExample:\\n```lua\\nlocal NettyClient = require(game:GetService(\\"ReplicatedStorage\\"):WaitForChild(\\"Commons\\")).Netty.Client\\nNettyClient.Start()\\n\\nNettyClient.FireServer(\\"my event\\", 123, CFrame.identity,\\"abc\\", workspace.MyPart) -- All of these arguments will be passed to the server.\\n```","params":[{"name":"eventId","desc":"The event id to trigger.","lua_type":"any"},{"name":"...","desc":"The arguments to pass to the server.","lua_type":"any"}],"returns":[],"function_type":"static","source":{"line":267,"path":"src/Commons/Netty/NettyClient.luau"}},{"name":"FireServerUnreliable","desc":"This function fires an unreliable remote event with proper data serialization to the server.\\n\\n:::note\\nEvents aren\'t fire instantly.  They\'re queued into an outbound pool, and a maximum of 255 events of each type(unreliable, reliable) are fired to the server at once per Heartbeat (RunService.Heartbeat).\\nThis function supports all data types, even if they aren\'t able to be serialized into buffers.\\nExample:\\n```lua\\nlocal NettyClient = require(game:GetService(\\"ReplicatedStorage\\"):WaitForChild(\\"Commons\\")).Netty.Client\\nNettyClient.Start()\\n\\nNettyClient.FireServerUnreliable(\\"my event\\", 123, CFrame.identity,\\"abc\\", workspace.MyPart) -- All of these arguments will be passed to the server.\\n```","params":[{"name":"eventId","desc":"The event id to trigger.","lua_type":"any"},{"name":"...","desc":"The arguments to pass to the server.","lua_type":"any"}],"returns":[],"function_type":"static","source":{"line":316,"path":"src/Commons/Netty/NettyClient.luau"}}],"properties":[],"types":[],"name":"NettyClient","desc":"NettyClient is the client module for the Netty framework.  It is used to handle all forms of inbound and outbound traffic.\\nNettyClient serializes any data it can into buffers.  Due to the nature of how Netty sends remote data, this approach to networking results in a significant decrease in outbound and inbound traffic, as well as lowering ping.","source":{"line":29,"path":"src/Commons/Netty/NettyClient.luau"}}')}}]);