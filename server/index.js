const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

/**
 * Encrypted Chat Pro Server - Version 2.0
 * Optimized for High Performance, WebRTC Signaling, and Android 14 Stability.
 */

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    },
    pingTimeout: 60000,
    pingInterval: 25000,
    connectTimeout: 45000,
    maxHttpBufferSize: 1e7 // 10MB for encrypted media chunks if needed
});

// User Registry: Maps userId -> socketId
const users = new Map();

// Logging Helper
const log = (msg) => {
    console.log(`[${new Date().toLocaleTimeString()}] ${msg}`);
};

io.on('connection', (socket) => {
    const userId = socket.handshake.query.userId;

    if (!userId || userId === 'unknown' || userId === 'null') {
        log(`[!] Rejected connection from ${socket.id} (Invalid userId)`);
        socket.disconnect(true);
        return;
    }

    // Register/Update User
    users.set(userId, socket.id);
    socket.join(userId); // Use userId as room name for 1-to-1 routing

    log(`[+] User Online: ${userId} | Total Connections: ${users.size}`);

    // Broadcast global status update
    socket.broadcast.emit('status', { userId, online: true });

    /**
     * WebRTC Signaling
     * Routes Offer, Answer, and Ice Candidates between peers
     */
    socket.on('signaling', (data) => {
        const targetId = data.targetId || data.target;
        if (targetId) {
            log(`[Signal] ${data.type || 'ICE'} from ${userId} to ${targetId}`);
            io.to(targetId).emit('signaling', { ...data, senderId: userId });
        }
    });

    /**
     * Encrypted Messaging
     */
    socket.on('message', (data) => {
        const targetId = data.targetId;
        if (targetId) {
            log(`[Msg] From ${userId} to ${targetId}`);
            io.to(targetId).emit('message', { ...data, senderId: userId });
        }
    });

    /**
     * Typing Indicator
     */
    socket.on('typing', (data) => {
        const targetId = data.targetId;
        if (targetId) {
            io.to(targetId).emit('typing', { userId, isTyping: data.isTyping });
        }
    });

    /**
     * Acknowledgments (Read/Delivery Receipts)
     */
    socket.on('read', (data) => {
        if (data.targetId) {
            io.to(data.targetId).emit('read', { ...data, senderId: userId });
        }
    });

    socket.on('delivery_status', (data) => {
        if (data.targetId) {
            io.to(data.targetId).emit('delivery_status', { ...data, senderId: userId });
        }
    });

    /**
     * Status Management
     */
    socket.on('get_user_status', (data) => {
        const isOnline = users.has(data.targetId);
        socket.emit('status', { userId: data.targetId, online: isOnline });
    });

    /**
     * Resource Cleanup
     */
    socket.on('disconnect', (reason) => {
        if (users.get(userId) === socket.id) {
            users.delete(userId);
            log(`[-] User Offline: ${userId} (Reason: ${reason})`);
            io.emit('status', { userId, online: false });
        }
    });

    socket.on('error', (err) => {
        log(`[Error] Socket ${userId}: ${err.message}`);
    });
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).send({ status: 'UP', users: users.size });
});

const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';

server.listen(PORT, HOST, () => {
    console.log(`
    ============================================
    🛡️  ENCRYPTED CHAT SERVER V2.0 IS ACTIVE
    ============================================
    🌐 URL: http://${HOST}:${PORT}
    📡 Monitoring active...
    ============================================
    `);
});
