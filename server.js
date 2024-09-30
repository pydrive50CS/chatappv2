const WebSocket = require("ws");
const wss = new WebSocket.Server({ port: 8080 });

// Track connected users and rooms
const users = {};
const rooms = {};
const roomUsers = {};

// Function to send a message to a specific room
function sendToRoom(roomId, data) {
  if (rooms[roomId]) {
    rooms[roomId].forEach((client) => {
      client.send(JSON.stringify(data));
    });
  }
}

// Function to broadcast the status of all users in a room
function broadcastRoomStatus(roomId) {
  console.log("Broadcast called:", roomUsers);
  if (roomUsers[roomId]) {
    const onlineUsers = Array.from(roomUsers[roomId]); // Get a list of userIds
    sendToRoom(roomId, { type: "statusUpdate", users: onlineUsers });
  }
}

// Function to add user to a room
function joinRoom(roomId, ws, userId) {
  if (!rooms[roomId]) {
    rooms[roomId] = new Set();
    roomUsers[roomId] = new Set();
  }
  rooms[roomId].add(ws); // Add WebSocket to the room
  roomUsers[roomId].add(userId); // Track userId in the room
  users[userId] = ws; // Map userId to WebSocket

  // Notify others about the updated status
  broadcastRoomStatus(roomId);
}

// Function to remove user from room on disconnect
function leaveRoom(roomId, ws, userId) {
  if (rooms[roomId]) {
    rooms[roomId].delete(ws); // Remove the WebSocket connection from the room
    roomUsers[roomId].delete(userId); // Remove userId from the room

    if (rooms[roomId].size === 0) {
      delete rooms[roomId]; // Clean up empty rooms
      delete roomUsers[roomId]; // Clean up user list for the room
    }
  }
  delete users[userId]; // Remove user from the users list

  // Notify others in the room that this user is offline
  broadcastRoomStatus(roomId);
}

wss.on("connection", (ws) => {
  console.log("Attempt to join has been made");
  let userId;
  let roomId;
  ws.on("message", (message) => {
    const data = JSON.parse(message);

    // Handle room joining
    if (data.type === "join") {
      userId = data.userId;
      roomId = data.roomId;
      joinRoom(roomId, ws, userId);

      console.log(`${userId} joined room ${roomId}`);
    }

    // Handle sending messages to a room
    else if (data.type === "message") {
      const messageData = {
        type: "message",
        id: data.id,
        sender: data.sender,
        text: data.text,
        roomId: roomId,
        messageType: data.messageType,
        timeStamp: new Date().toISOString(),
      };
      sendToRoom(roomId, messageData); // Send message to everyone in the room

      console.log(`Message from ${data.sender}: ${data.text}`);
    }

    // Handle typing indicator
    else if (data.type === "typing") {
      const typingData = {
        type: "typing",
        sender: data.sender,
        roomId: roomId,
      };
      sendToRoom(roomId, typingData); // Notify others in the room who is typing

      console.log(`${data.sender} is typing...`);
    } else if (data.type === "stopped_typing") {
      const typingData = {
        type: "stopped_typing",
        sender: data.sender,
        roomId: roomId,
      };
      sendToRoom(roomId, typingData); // Notify others that typing has stopped

      console.log(`${data.sender} stopped typing.`);
    } else if (data.type === "ping") {
      console.log(`Received ping from client ${data.sender}`);
      ws.send(JSON.stringify({ type: "pong" }));
    } else if (data.type === "disconnect") {
      const userId = data.userId;
      if (roomId && userId) {
        leaveRoom(roomId, ws, userId);
        console.log(`${userId} disconnected from room ${roomId}`);
      }
    }
  });

  // Handle disconnects
  ws.on("close", () => {
    if (userId && roomId) {
      leaveRoom(roomId, ws, userId);

      console.log(`${userId} left room ${roomId}`);
    }
  });
});

console.log("WebSocket server is running on ws://localhost:8080");
