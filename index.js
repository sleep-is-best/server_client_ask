const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const cors = require('cors');

const app = express();
const server3000 = http.createServer(app);
const server3001 = http.createServer(app);
const server3002 = http.createServer(app);

// --- Configuration & Folders ---
const PORT_MAIN = 3000;
const PORT_MEDIA = 3001;
const PORT_CALL = 3002;
const DATA_ROOT = path.join(__dirname, 'ServerData');
const DIRS = [
    'Students',
    'Questions',
    'Messages',
    'Points',
    'Uploads',
    'Answers',
    'AdminLogs',
    'Reports',
    'PendingMessages',
    'Reels',
    'Library',
    'Materials',
    'Bookmarks',
    'Badges',
    'Follows',
    'ReputationHistory',
    'Uploads/Images',
    'Uploads/Videos',
    'Uploads/Audio',
    'Uploads/Files',
    'Uploads/Temp',
    'Uploads/Temp/Images',
    'Uploads/Temp/Videos',
    'Uploads/Temp/Audio',
    'Uploads/Temp/Files'
];

// Ensure directory structure
if (!fs.existsSync(DATA_ROOT)) fs.mkdirSync(DATA_ROOT);
DIRS.forEach(dir => {
    const dirPath = path.join(DATA_ROOT, dir);
    if (!fs.existsSync(dirPath)) fs.mkdirSync(dirPath, { recursive: true });
});

// Initialize default library data if empty
const libraryPath = path.join(DATA_ROOT, 'Library');
if (fs.existsSync(libraryPath) && fs.readdirSync(libraryPath).length === 0) {
    storage.write('Library', 'specializations', [
        { id: '1', name: 'طب بشري' },
        { id: '2', name: 'هندسة معلوماتية' },
        { id: '3', name: 'صيدلة' },
        { id: '4', name: 'حقوق' }
    ]);
    storage.write('Library', 'levels', [
        { id: '1', specializationId: '1', name: 'السنة الأولى' },
        { id: '2', specializationId: '1', name: 'السنة الثانية' },
        { id: '3', specializationId: '2', name: 'السنة الأولى' }
    ]);
    storage.write('Library', 'subjects', [
        { id: '1', levelId: '1', semesterId: '1', name: 'تشريح 1' },
        { id: '2', levelId: '1', semesterId: '1', name: 'فيزياء طبية' },
        { id: '3', levelId: '3', semesterId: '1', name: 'خوارزميات 1' }
    ]);
}

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(DATA_ROOT, 'Uploads')));
app.use('/uploads/Images', express.static(path.join(DATA_ROOT, 'Uploads', 'Images')));
app.use('/uploads/Videos', express.static(path.join(DATA_ROOT, 'Uploads', 'Videos')));
app.use('/uploads/Audio', express.static(path.join(DATA_ROOT, 'Uploads', 'Audio')));
app.use('/uploads/Files', express.static(path.join(DATA_ROOT, 'Uploads', 'Files')));

// --- Logger ---
const logger = {
    info: (msg, data = '') => console.log(`[\x1b[36mINFO\x1b[0m] [${new Date().toLocaleTimeString()}] ${msg}`, data),
    success: (msg) => console.log(`[\x1b[32mOK\x1b[0m] [${new Date().toLocaleTimeString()}] ${msg}`),
    warn: (msg, data = '') => console.warn(`[\x1b[33mWARN\x1b[0m] [${new Date().toLocaleTimeString()}] ${msg}`, data),
    error: (msg, err = '') => console.error(`[\x1b[31mERROR\x1b[0m] [${new Date().toLocaleTimeString()}] ${msg}`, err)
};

const ROLES = {
    MEMBER: 'member',
    PREMIUM: 'premium_member',
    TEACHER: 'teacher',
    DOCTOR: 'doctor',
    ASSISTANT: 'assistant_admin',
    ADMIN: 'admin'
};

const MAIN_ADMIN_ID = 'STU-527174';
const MAIN_ADMIN_PHONE = '774632182';

const ROLE_PERMISSIONS = {
    [ROLES.MEMBER]: [],
    [ROLES.PREMIUM]: [],
    [ROLES.TEACHER]: ['delete_questions'],
    [ROLES.DOCTOR]: ['delete_questions'],
    [ROLES.ASSISTANT]: [
        'view_admin_panel',
        'manage_members',
        'promote_members',
        'ban_members',
        'unban_members',
        'delete_questions',
        'view_reports',
        'send_admin_notifications'
    ],
    [ROLES.ADMIN]: [
        'view_admin_panel',
        'manage_members',
        'promote_members',
        'ban_members',
        'unban_members',
        'delete_questions',
        'delete_members',
        'send_admin_notifications',
        'manage_roles',
        'view_reports',
        'view_admin_logs'
    ]
};

// --- Storage Engine (Atomic JSON) ---
const storage = {
    read: (folder, filename) => {
        const filePath = path.join(DATA_ROOT, folder, `${filename}.json`);
        if (!fs.existsSync(filePath)) return null;
        try {
            return JSON.parse(fs.readFileSync(filePath, 'utf8'));
        } catch (e) {
            logger.error(`Read error: ${filename}`, e);
            return null;
        }
    },
    write: (folder, filename, data) => {
        const filePath = path.join(DATA_ROOT, folder, `${filename}.json`);
        const tempPath = filePath + '.tmp';
        try {
            fs.writeFileSync(tempPath, JSON.stringify(data, null, 2));
            if (fs.existsSync(filePath)) {
                fs.unlinkSync(filePath);
            }
            fs.renameSync(tempPath, filePath);
            return true;
        } catch (e) {
            logger.error(`Write error: ${filename}`, e);
            return false;
        }
    },
    appendList: (folder, filename, item) => {
        let list = storage.read(folder, filename) || [];
        list.push(item);
        storage.write(folder, filename, list);
    },
    readList: (folder, filename) => storage.read(folder, filename) || []
};

// --- Helper for Temporary Storage Migration ---
const moveFileFromTemp = (url, studentId) => {
    if (!url || !url.includes('/Temp/')) return url;
    try {
        const filename = path.basename(url);
        let subFolder = 'Files';
        if (url.includes('/Images/')) subFolder = 'Images';
        else if (url.includes('/Videos/')) subFolder = 'Videos';
        else if (url.includes('/Audio/')) subFolder = 'Audio';

        const oldPath = path.join(DATA_ROOT, 'Uploads', 'Temp', subFolder, studentId, filename);
        const newDir = path.join(DATA_ROOT, 'Uploads', subFolder, studentId);
        const newPath = path.join(newDir, filename);

        if (fs.existsSync(oldPath)) {
            if (!fs.existsSync(newDir)) fs.mkdirSync(newDir, { recursive: true });
            fs.renameSync(oldPath, newPath);
            return url.replace('/Temp/', '/');
        }
    } catch (e) {
        logger.error(`Error moving temp file: ${url}`, e);
    }
    return url;
};

// --- Multer Configuration ---
const uploadStorage = multer.diskStorage({
    destination: (req, file, cb) => {
        const authId = req.headers['x-student-id'];
        const bodyId = req.body.studentId;
        const type = req.body.type || req.query.type || 'file';

        // Strict Validation: Verify studentId matches authenticated session if provided in body
        if (bodyId && authId && bodyId !== authId) {
            return cb(new Error('Unauthorized: Student ID mismatch'));
        }

        // Strict Validation: Verify type is valid
        if (!['image', 'video', 'audio', 'file'].includes(type)) {
            return cb(new Error('Invalid upload type'));
        }

        const studentId = authId || bodyId || 'unknown';
        const isTemp = req.body.isTemp === 'true' || req.query.isTemp === 'true';

        let subFolder = 'Files';
        if (type === 'image') subFolder = 'Images';
        else if (type === 'video') subFolder = 'Videos';
        else if (type === 'audio') subFolder = 'Audio';

        let base = path.join(DATA_ROOT, 'Uploads');
        if (isTemp) {
            base = path.join(base, 'Temp');
        }

        const dest = path.join(base, subFolder, studentId);
        if (!fs.existsSync(dest)) fs.mkdirSync(dest, { recursive: true });
        cb(null, dest);
    },
    filename: (req, file, cb) => {
        const studentId = req.headers['x-student-id'] || req.body.studentId || 'unknown';
        const suffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, studentId + '-' + suffix + path.extname(file.originalname));
    }
});
const upload = multer({ storage: uploadStorage, limits: { fileSize: 100 * 1024 * 1024 } });

// --- Core Data Controllers ---
const Students = {
    getAll: () => storage.readList('Students', 'master'),
    getById: (id) => Students.getAll().find(s => s.studentId === id),
    getByPhone: (phone) => Students.getAll().find(s => s.phone === phone),
    update: (studentData) => {
        let all = Students.getAll();
        const index = all.findIndex(s => s.studentId === studentData.studentId);
        if (index !== -1) {
            const { studentId, points, createdAt, ...updates } = studentData; // Prevent changing ID or Points directly
            all[index] = { ...all[index], ...updates };
            storage.write('Students', 'master', all);
            return all[index];
        }
        return null;
    },
    register: (name, phone) => {
        let all = Students.getAll();
        const existing = all.find(s => s.phone === phone);
        if (existing) return existing;

        let studentId = 'STU-' + Math.floor(100000 + Math.random() * 900000);
        let role = ROLES.MEMBER;

        // Auto-assign main admin
        if (phone === MAIN_ADMIN_PHONE) {
            role = ROLES.ADMIN;
            studentId = MAIN_ADMIN_ID; // Use fixed ID for main admin
        }

        const newStudent = {
            studentId,
            name,
            phone,
            bio: '',
            profileImage: null,
            backgroundImage: null,
            points: 0,
            role,
            isBanned: false,
            banReason: null,
            banUntil: null,
            following: [],
            followers: [],
            blockedUsers: [],
            createdAt: new Date().toISOString(),
            lastSeen: new Date().toISOString()
        };
        all.push(newStudent);
        storage.write('Students', 'master', all);
        storage.write('Points', studentId, { studentId, history: [], total: 0 });
        return newStudent;
    },
    setRole: (studentId, newRole, adminId) => {
        let all = Students.getAll();
        const index = all.findIndex(s => s.studentId === studentId);
        if (index === -1) return null;

        // Cannot change main admin role
        if (all[index].phone === MAIN_ADMIN_PHONE) return null;

        all[index].role = newRole;
        storage.write('Students', 'master', all);
        AdminLogs.add(adminId, 'CHANGE_ROLE', studentId, `Changed role to ${newRole}`);
        return all[index];
    },
    ban: (studentId, reason, until, adminId) => {
        let all = Students.getAll();
        const index = all.findIndex(s => s.studentId === studentId);
        if (index === -1) return null;

        // Cannot ban main admin
        if (all[index].phone === MAIN_ADMIN_PHONE) return null;

        all[index].isBanned = true;
        all[index].banReason = reason;
        all[index].banUntil = until; // null for permanent, or ISO date
        storage.write('Students', 'master', all);
        AdminLogs.add(adminId, 'BAN_USER', studentId, reason);
        return all[index];
    },
    unban: (studentId, adminId) => {
        let all = Students.getAll();
        const index = all.findIndex(s => s.studentId === studentId);
        if (index === -1) return null;

        all[index].isBanned = false;
        all[index].banReason = null;
        all[index].banUntil = null;
        storage.write('Students', 'master', all);
        AdminLogs.add(adminId, 'UNBAN_USER', studentId);
        return all[index];
    },
    delete: (studentId, adminId) => {
        let all = Students.getAll();
        const student = all.find(s => s.studentId === studentId);
        if (!student || student.phone === MAIN_ADMIN_PHONE) return false;

        all = all.filter(s => s.studentId !== studentId);
        storage.write('Students', 'master', all);
        AdminLogs.add(adminId, 'DELETE_USER', studentId);
        return true;
    }
};

const AdminLogs = {
    add: (adminId, action, targetId, reason = '') => {
        const log = {
            id: Date.now().toString(),
            adminId,
            action,
            targetId,
            reason,
            timestamp: new Date().toISOString()
        };
        storage.appendList('AdminLogs', 'master', log);
    },
    getAll: () => storage.readList('AdminLogs', 'master')
};

const Reports = {
    add: (reporterId, targetType, targetId, reason) => {
        const report = {
            id: Date.now().toString(),
            reporterId,
            targetType, // 'question', 'answer', 'user'
            targetId,
            reason,
            status: 'pending',
            createdAt: new Date().toISOString()
        };
        storage.appendList('Reports', 'master', report);
        return report;
    },
    updateStatus: (reportId, status, adminId) => {
        let all = storage.readList('Reports', 'master');
        const index = all.findIndex(r => r.id === reportId);
        if (index !== -1) {
            all[index].status = status;
            all[index].reviewedBy = adminId;
            all[index].reviewedAt = new Date().toISOString();
            storage.write('Reports', 'master', all);
            return all[index];
        }
        return null;
    },
    getAll: () => storage.readList('Reports', 'master')
};

const Points = {
    add: (studentId, amount, reason) => {
        let data = storage.read('Points', studentId) || { studentId, history: [], total: 0 };
        data.total += amount;
        data.history.push({ amount, reason, timestamp: new Date().toISOString() });
        storage.write('Points', studentId, data);

        const student = Students.getById(studentId);
        if (student) {
            student.points = data.total;
            // Atomic update in master
            let all = Students.getAll();
            const idx = all.findIndex(s => s.studentId === studentId);
            if (idx !== -1) {
                all[idx].points = data.total;
                storage.write('Students', 'master', all);
            }
        }
        return data.total;
    }
};

// --- Middleware & Auth Helpers ---
const checkPermission = (id, permission) => {
    if (isMainAdmin(id)) return true; // Main admin has all permissions

    const student = Students.getById(id) || Students.getByPhone(id);
    if (!student) return false;

    if (student.isBanned) {
        if (!student.banUntil || new Date(student.banUntil) > new Date()) return false;
        // Auto-unban if time expired
        Students.unban(student.studentId, 'SYSTEM');
    }
    const role = student.role || ROLES.MEMBER;
    const perms = ROLE_PERMISSIONS[role] || [];
    return perms.includes(permission);
};

const isMainAdmin = (id) => {
    if (!id) return false;
    const sId = id.toString().trim();
    if (sId === MAIN_ADMIN_ID || sId === 'STU-527174' || sId === MAIN_ADMIN_PHONE) return true;
    const student = Students.getById(sId) || Students.getByPhone(sId);
    return student && student.phone === MAIN_ADMIN_PHONE;
};

const isAdmin = (id) => {
    if (isMainAdmin(id)) return true;
    const student = Students.getById(id) || Students.getByPhone(id);
    return student && (student.role === ROLES.ADMIN || student.role === ROLES.ASSISTANT);
};

// --- API Endpoints ---
app.get('/api/admin/stats', (req, res) => {
    const studentId = req.headers['x-student-id'];
    if (!isAdmin(studentId)) return res.status(403).json({ error: 'Access denied' });

    const allStudents = Students.getAll();
    const questions = storage.readList('Questions', 'all');
    const reels = storage.readList('Reels', 'all') || [];
    const reports = storage.readList('Reports', 'all') || [];
    const materials = storage.readList('Materials', 'all') || [];

    res.json({
        totalMembers: allStudents.length,
        onlineMembers: Array.from(activeUsers.keys()).length,
        bannedMembers: allStudents.filter(s => s.isBanned).length,
        premiumMembers: allStudents.filter(s => s.role === ROLES.PREMIUM).length,
        teachers: allStudents.filter(s => s.role === ROLES.TEACHER).length,
        doctors: allStudents.filter(s => s.role === ROLES.DOCTOR).length,
        assistants: allStudents.filter(s => s.role === ROLES.ASSISTANT).length,
        questionsCount: questions.length,
        reelsCount: reels.length,
        reportsCount: reports.length,
        pendingMaterialsCount: materials.filter(m => m.status === 'pending').length,
        deletedQuestionsCount: storage.readList('AdminLogs', 'master').filter(l => l.action === 'DELETE_QUESTION').length
    });
});

app.get('/api/admin/members', (req, res) => {
    const studentId = req.headers['x-student-id'];
    if (!isAdmin(studentId)) return res.status(403).json({ error: 'Access denied' });

    const all = Students.getAll().map(s => ({
        ...s,
        online: activeUsers.has(s.studentId)
    }));
    res.json(all);
});

app.post('/api/student/follow/:targetId', (req, res) => {
    const myId = req.headers['x-student-id'];
    const targetId = req.params.targetId;

    if (!myId || !targetId || myId === targetId) return res.status(400).json({ error: 'Invalid ID' });

    let all = Students.getAll();
    const myIdx = all.findIndex(s => s.studentId === myId);
    const targetIdx = all.findIndex(s => s.studentId === targetId);

    if (myIdx === -1 || targetIdx === -1) return res.status(404).json({ error: 'User not found' });

    if (!all[myIdx].following) all[myIdx].following = [];
    if (!all[targetIdx].followers) all[targetIdx].followers = [];

    const isFollowing = all[myIdx].following.includes(targetId);

    if (!isFollowing) {
        all[myIdx].following.push(targetId);
        all[targetIdx].followers.push(myId);
        Points.add(targetId, 5, 'New follower');
    }

    storage.write('Students', 'master', all);
    res.json({ following: true, followersCount: all[targetIdx].followers.length });
});

app.delete('/api/student/follow/:targetId', (req, res) => {
    const myId = req.headers['x-student-id'];
    const targetId = req.params.targetId;

    let all = Students.getAll();
    const myIdx = all.findIndex(s => s.studentId === myId);
    const targetIdx = all.findIndex(s => s.studentId === targetId);

    if (myIdx === -1 || targetIdx === -1) return res.status(404).json({ error: 'User not found' });

    if (all[myIdx].following) {
        all[myIdx].following = all[myIdx].following.filter(id => id !== targetId);
    }
    if (all[targetIdx].followers) {
        all[targetIdx].followers = all[targetIdx].followers.filter(id => id !== myId);
    }

    storage.write('Students', 'master', all);
    res.json({ following: false, followersCount: (all[targetIdx].followers || []).length });
});

app.post('/api/student/block/:targetId', (req, res) => {
    const myId = req.headers['x-student-id'];
    const targetId = req.params.targetId;

    if (!myId || !targetId || myId === targetId) return res.status(400).json({ error: 'Invalid ID' });

    let all = Students.getAll();
    const myIdx = all.findIndex(s => s.studentId === myId);

    if (myIdx === -1) return res.status(404).json({ error: 'User not found' });

    if (!all[myIdx].blockedUsers) all[myIdx].blockedUsers = [];
    if (!all[myIdx].blockedUsers.includes(targetId)) {
        all[myIdx].blockedUsers.push(targetId);
        // Also unfollow if blocking
        if (all[myIdx].following) all[myIdx].following = all[myIdx].following.filter(id => id !== targetId);

        storage.write('Students', 'master', all);
    }

    res.json({ blocked: true });
});

app.post('/api/admin/promote', (req, res) => {
    const adminId = req.headers['x-student-id'];
    const { targetId, role } = req.body;

    if (!checkPermission(adminId, 'promote_members')) {
        return res.status(403).json({ error: 'ليس لديك صلاحية ترقية الأعضاء' });
    }

    // Safety: only main admin can promote to assistant/admin
    if ((role === ROLES.ASSISTANT || role === ROLES.ADMIN) && !isMainAdmin(adminId)) {
        return res.status(403).json({ error: 'فقط المدير العام يمكنه تعيين مديرين أو مساعدين' });
    }

    const updated = Students.setRole(targetId, role, adminId);
    if (updated) {
        io.to(targetId).emit('role_updated', { role: updated.role });
        res.json(updated);
    } else {
        res.status(400).json({ error: 'فشلت عملية الترقية: المستخدم غير موجود أو محمي' });
    }
});

app.post('/api/admin/ban', (req, res) => {
    const adminId = req.headers['x-student-id'];
    const { targetId, reason, duration } = req.body;

    if (!checkPermission(adminId, 'ban_members')) return res.status(403).json({ error: 'Forbidden' });

    let until = null;
    if (duration && duration !== 'permanent') {
        until = new Date(Date.now() + parseInt(duration) * 60000).toISOString();
    }

    const updated = Students.ban(targetId, reason, until, adminId);
    if (updated) {
        io.to(targetId).emit('banned', { reason, until });
        // Optionally disconnect the user
        const userSockets = activeUsers.get(targetId);
        if (userSockets) {
            userSockets.forEach(sid => io.sockets.sockets.get(sid)?.disconnect());
        }
        res.json(updated);
    } else {
        res.status(400).json({ error: 'Ban failed' });
    }
});

app.post('/api/admin/unban', (req, res) => {
    const adminId = req.headers['x-student-id'];
    const { targetId } = req.body;

    if (!checkPermission(adminId, 'unban_members')) return res.status(403).json({ error: 'Forbidden' });

    const updated = Students.unban(targetId, adminId);
    if (updated) {
        io.to(targetId).emit('unbanned');
        res.json(updated);
    } else {
        res.status(400).json({ error: 'Unban failed' });
    }
});

app.delete('/api/admin/questions/:questionId', (req, res) => {
    const adminId = req.headers['x-student-id'];
    const { questionId } = req.params;

    if (!checkPermission(adminId, 'delete_questions')) return res.status(403).json({ error: 'Forbidden' });

    let allQ = storage.readList('Questions', 'all');
    const index = allQ.findIndex(q => q.id == questionId);

    if (index !== -1) {
        const question = allQ[index];
        allQ.splice(index, 1);
        storage.write('Questions', 'all', allQ);

        AdminLogs.add(adminId, 'DELETE_QUESTION', questionId, `Deleted question by ${question.userId}`);

        // Remove answers file
        const answersPath = path.join(DATA_ROOT, 'Questions', `answers_${questionId}.json`);
        if (fs.existsSync(answersPath)) fs.unlinkSync(answersPath);

        io.emit('question_deleted', { questionId });
        res.json({ success: true });
    } else {
        res.status(404).json({ error: 'Question not found' });
    }
});

app.delete('/api/admin/reels/:reelId', (req, res) => {
    const adminId = req.headers['x-student-id'];
    const { reelId } = req.params;

    if (!isAdmin(adminId)) return res.status(403).json({ error: 'Forbidden' });

    let allReels = storage.readList('Reels', 'all');
    const index = allReels.findIndex(r => r.id === reelId);

    if (index !== -1) {
        const reel = allReels[index];
        allReels.splice(index, 1);
        storage.write('Reels', 'all', allReels);

        AdminLogs.add(adminId, 'DELETE_REEL', reelId, `Deleted reel by ${reel.userId}`);
        res.json({ success: true });
    } else {
        res.status(404).json({ error: 'Reel not found' });
    }
});

app.post('/api/report', (req, res) => {
    const reporterId = req.headers['x-student-id'];
    const { targetType, targetId, reason } = req.body;
    const report = Reports.add(reporterId, targetType, targetId, reason);
    res.json(report);
});

app.post('/api/activity/report', (req, res) => {
    const studentId = req.headers['x-student-id'];
    const { action } = req.body;
    logger.info(`Activity reported by ${studentId}: ${action}`);
    res.json({ success: true });
});

app.get('/api/admin/reports', (req, res) => {
    const adminId = req.headers['x-student-id'];
    if (!checkPermission(adminId, 'view_reports')) return res.status(403).json({ error: 'Forbidden' });
    res.json(Reports.getAll());
});

app.get('/api/admin/logs', (req, res) => {
    const adminId = req.headers['x-student-id'];
    if (!checkPermission(adminId, 'view_admin_logs')) return res.status(403).json({ error: 'Forbidden' });
    res.json(AdminLogs.getAll());
});


app.get('/api/notifications', (req, res) => {
    const studentId = req.headers['x-student-id'];
    if (!studentId) return res.status(400).json({ error: 'Missing student ID' });
    res.json(storage.readList('Notifications', studentId));
});

app.post('/api/register', (req, res) => {
    const { name, phone } = req.body;
    if (!name || !phone) return res.status(400).json({ error: 'Name and phone required' });
    const student = Students.register(name, phone);
    res.json(student);
});

app.post('/api/login', (req, res) => {
    const { phone, studentId, name } = req.body;
    let student;
    if (studentId) {
        student = Students.getById(studentId);
    } else if (phone) {
        student = Students.getByPhone(phone);
    }

    // Auto-register for testing resilience
    if (!student && phone) {
        student = Students.register(name || 'New User', phone);
        logger.info(`Auto-registered user on login: ${phone}`);
    }

    if (!student) return res.status(404).json({ error: 'Student not found' });
    res.json(student);
});

app.get('/api/student/profile/:id', (req, res) => {
    const student = Students.getById(req.params.id);
    if (!student) return res.status(404).json({ error: 'Not found' });
    res.json(student);
});

app.get('/api/student/find-by-phone', (req, res) => {
    const phone = req.query.phone;
    if (!phone) return res.status(400).json({ error: 'Phone required' });
    const student = Students.getByPhone(phone);
    if (!student) return res.status(404).json({ error: 'Not found' });
    res.json(student);
});

app.post('/api/student/update', (req, res) => {
    const authId = req.headers['x-student-id'];
    if (!authId || (req.body.studentId && req.body.studentId !== authId)) {
        return res.status(403).json({ error: 'Unauthorized: Cannot update another user\'s profile' });
    }

    // Ensure we are updating the correct student
    const updateData = { ...req.body, studentId: authId };
    const student = Students.update(updateData);
    if (!student) return res.status(400).json({ error: 'Update failed' });
    res.json(student);
});

app.post('/api/student/change-phone', (req, res) => {
    const { studentId, newPhone } = req.body;
    const authId = req.headers['x-student-id'];
    if (!authId || studentId !== authId) {
        return res.status(403).json({ error: 'Unauthorized' });
    }

    let all = Students.getAll();
    const index = all.findIndex(s => s.studentId === studentId);
    if (index === -1) return res.status(404).json({ error: 'Student not found' });

    if (all.some(s => s.phone === newPhone && s.studentId !== studentId)) {
        return res.status(400).json({ error: 'Phone already in use' });
    }

    all[index].phone = newPhone;
    storage.write('Students', 'master', all);
    res.json(all[index]);
});

app.post('/api/upload', (req, res, next) => {
    // محاولة الحصول على المعرف من عدة مصادر
    const studentId = req.headers['x-student-id'] || req.query.studentId;
    const type = req.body.type || req.query.type || 'file';

    // إذا لم يتوفر المعرف في الهيدر أو الكويري، ننتظر حتى يقوم multer بمعالجة الـ body
    if (!studentId && req.headers['content-type']?.includes('multipart/form-data')) {
        return next();
    }

    if (!studentId) return res.status(400).json({ error: 'Missing student ID' });

    const student = Students.getById(studentId);
    if (!student) return res.status(404).json({ error: 'Student not found' });

    // Validation for type and studentId consistency (if fields are present before file)
    if (req.body.studentId && req.body.studentId !== studentId) {
        return res.status(403).json({ error: 'Student ID mismatch' });
    }

    if (!['image', 'video', 'audio', 'file'].includes(type)) {
        return res.status(400).json({ error: 'Invalid upload type' });
    }

    const isTemp = req.body.isTemp === 'true' || req.query.isTemp === 'true';

    if (type === 'file' && !isTemp) { // Only check permissions for permanent library uploads
        const canUpload = isAdmin(studentId) ||
                          student.role === ROLES.TEACHER ||
                          student.role === ROLES.DOCTOR ||
                          (student.role === ROLES.MEMBER && (student.points || 0) >= 1000);

        if (!canUpload) {
            return res.status(403).json({ error: 'ليس لديك صلاحية لرفع الملخصات. يجب أن يكون لديك 1000 نقطة على الأقل.' });
        }
    }

    next();
}, upload.single('file'), (req, res) => {
    if (!req.file) return res.status(400).json({ error: 'No file' });

    // بعد معالجة multer، المعرف سيكون متاحاً في req.body إذا أرسله العميل كحقل
    const studentId = req.headers['x-student-id'] || req.body.studentId || req.query.studentId || 'unknown';
    const type = req.body.type || req.query.type || 'file';
    const isTemp = req.body.isTemp === 'true' || req.query.isTemp === 'true';

    logger.info(`Finalizing upload: ${type} from student ${studentId}`);

    let subFolder = 'Files';
    if (type === 'image') subFolder = 'Images';
    else if (type === 'video') subFolder = 'Videos';
    else if (type === 'audio') subFolder = 'Audio';

    const pathPart = isTemp ? `Temp/${subFolder}` : subFolder;
    const fileUrl = `${req.protocol}://${req.get('host')}/uploads/${pathPart}/${studentId}/${req.file.filename}`;

    logger.info(`File uploaded (${isTemp ? 'TEMP' : 'PERM'}): ${req.file.filename} for student ${studentId}`);
    res.json({ url: fileUrl });
});

app.delete('/api/upload/temp', (req, res) => {
    const { url } = req.body;
    const studentId = req.headers['x-student-id'];
    if (!url || !studentId) return res.status(400).json({ error: 'Missing data' });

    if (!url.includes('/Temp/')) return res.status(400).json({ error: 'Not a temp file' });

    try {
        const filename = path.basename(url);
        const typeFolder = url.includes('/Images/')
            ? 'Images'
            : (url.includes('/Videos/') ? 'Videos' : (url.includes('/Audio/') ? 'Audio' : 'Files'));
        const filePath = path.join(DATA_ROOT, 'Uploads', 'Temp', typeFolder, studentId, filename);

        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
            return res.json({ success: true });
        }
    } catch (e) {
        logger.error(`Error deleting temp file: ${url}`, e);
    }
    res.status(404).json({ error: 'File not found' });
});

app.get('/api/questions', (req, res) => {
    res.json(storage.readList('Questions', 'all'));
});

app.get('/api/questions/my/:studentId', (req, res) => {
    const all = storage.readList('Questions', 'all');
    res.json(all.filter(q => q.userId === req.params.studentId));
});

app.get('/api/questions/:id/answers', (req, res) => {
    res.json(storage.readList('Questions', `answers_${req.params.id}`));
});

app.get('/api/reels', (req, res) => {
    const { page = 1, limit = 10, type = 'feed', userId } = req.query;
    const myUserId = req.headers['x-student-id'];
    const allReels = storage.readList('Reels', 'all');

    let enhancedReels = allReels.map(reel => {
        const student = Students.getById(reel.userId);
        return {
            ...reel,
            creatorName: student ? student.name : 'Unknown',
            creatorProfileImage: student ? student.profileImage : null,
            creatorRole: student ? student.role : 'member'
        };
    });

    let reels = [...enhancedReels];

    if (type === 'user' && userId) {
        reels = reels.filter(r => r.userId === userId);
    } else if (type === 'following' && myUserId) {
        const me = Students.getById(myUserId);
        const following = me ? (me.following || []) : [];
        reels = reels.filter(r => following.includes(r.userId));
        reels = reels.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    } else if (type === 'feed') {
        reels = reels.sort(() => Math.random() - 0.5);
    }

    const start = (page - 1) * limit;
    const end = page * limit;
    res.json(reels.slice(start, end));
});

app.post('/api/reels/create', (req, res) => {
    const authId = req.headers['x-student-id'];
    const { userId, videoUrl, caption, thumbnail, title, reference } = req.body;

    // Verify session
    if (authId && userId && authId !== userId) {
        return res.status(403).json({ error: 'Unauthorized: User ID mismatch' });
    }

    const targetId = authId || userId;
    const student = Students.getById(targetId) || Students.getByPhone(targetId);
    if (!student) return res.status(404).json({ error: 'المستخدم غير موجود' });

    // التحقق من النقاط: يجب توفر 1000 نقطة على الأقل (باستثناء المدير العام والمسؤولين)
    if (!isAdmin(userId) && (student.points || 0) < 1000) {
        return res.status(403).json({ error: 'عذراً، يجب أن يكون لديك 1000 نقطة على الأقل لنشر الريلز' });
    }

    // Move temp files
    const finalVideoUrl = moveFileFromTemp(videoUrl, student.studentId);
    const finalThumbnailUrl = moveFileFromTemp(thumbnail, student.studentId);

    const reel = {
        id: Date.now().toString(),
        userId: student.studentId, // Use fixed internal ID
        videoUrl: finalVideoUrl,
        title: title || '',
        caption: caption || '',
        reference: reference || '',
        thumbnail: finalThumbnailUrl || '',
        likes: [],
        comments: [],
        views: 0,
        shares: 0,
        timestamp: new Date().toISOString()
    };
    storage.appendList('Reels', 'all', reel);
    res.json(reel);
});

app.post('/api/reels/:id/like', (req, res) => {
    const userId = req.headers['x-student-id'];
    const reelId = req.params.id;
    let allReels = storage.readList('Reels', 'all');
    const index = allReels.findIndex(r => r.id === reelId);

    if (index !== -1) {
        const reel = allReels[index];
        const likeIndex = reel.likes.indexOf(userId);
        if (likeIndex === -1) {
            reel.likes.push(userId);
        } else {
            reel.likes.splice(likeIndex, 1);
        }
        storage.write('Reels', 'all', allReels);
        res.json({ liked: likeIndex === -1, count: reel.likes.length });
    } else {
        res.status(404).json({ error: 'Reel not found' });
    }
});

app.delete('/api/reels/:id/like', (req, res) => {
    const userId = req.headers['x-student-id'];
    const reelId = req.params.id;
    let allReels = storage.readList('Reels', 'all');
    const index = allReels.findIndex(r => r.id === reelId);

    if (index !== -1) {
        const reel = allReels[index];
        const likeIndex = reel.likes.indexOf(userId);
        if (likeIndex !== -1) {
            reel.likes.splice(likeIndex, 1);
            storage.write('Reels', 'all', allReels);
        }
        res.json({ liked: false, count: reel.likes.length });
    } else {
        res.status(404).json({ error: 'Reel not found' });
    }
});

app.post('/api/reels/:id/view', (req, res) => {
    const reelId = req.params.id;
    let allReels = storage.readList('Reels', 'all');
    const index = allReels.findIndex(r => r.id === reelId);

    if (index !== -1) {
        allReels[index].views = (allReels[index].views || 0) + 1;
        storage.write('Reels', 'all', allReels);
        res.json({ views: allReels[index].views });
    } else {
        res.status(404).json({ error: 'Reel not found' });
    }
});

app.delete('/api/reels/:id', (req, res) => {
    const studentId = req.headers['x-student-id'];
    const reelId = req.params.id;
    let allReels = storage.readList('Reels', 'all');
    const index = allReels.findIndex(r => r.id === reelId);

    if (index !== -1) {
        const reel = allReels[index];
        if (reel.userId === studentId || isAdmin(studentId)) {
            allReels.splice(index, 1);
            storage.write('Reels', 'all', allReels);
            res.json({ success: true });
        } else {
            res.status(403).json({ error: 'ليس لديك صلاحية حذف هذا الفيديو' });
        }
    } else {
        res.status(404).json({ error: 'Reel not found' });
    }
});

app.post('/api/reels/:id/comment', (req, res) => {
    const userId = req.headers['x-student-id'];
    const reelId = req.params.id;
    const { content } = req.body;

    if (!content) return res.status(400).json({ error: 'Comment content required' });

    let allReels = storage.readList('Reels', 'all');
    const index = allReels.findIndex(r => r.id === reelId);

    if (index !== -1) {
        const student = Students.getById(userId);
        const comment = {
            id: Date.now().toString(),
            userId,
            userName: student ? student.name : 'Unknown',
            userProfileImage: student ? student.profileImage : null,
            text: content,
            timestamp: new Date().toISOString()
        };
        if (!allReels[index].comments) allReels[index].comments = [];
        allReels[index].comments.push(comment);
        storage.write('Reels', 'all', allReels);
        res.json(comment);
    } else {
        res.status(404).json({ error: 'Reel not found' });
    }
});

app.get('/api/reels/:id/comments', (req, res) => {
    const reelId = req.params.id;
    let allReels = storage.readList('Reels', 'all');
    const index = allReels.findIndex(r => r.id === reelId);

    if (index !== -1) {
        res.json(allReels[index].comments || []);
    } else {
        res.status(404).json({ error: 'Reel not found' });
    }
});

app.delete('/api/reels/:id/comments/:commentId', (req, res) => {
    const userId = req.headers['x-student-id'];
    const { id: reelId, commentId } = req.params;

    let allReels = storage.readList('Reels', 'all');
    const reelIndex = allReels.findIndex(r => r.id === reelId);

    if (reelIndex !== -1) {
        const reel = allReels[reelIndex];
        const commentIndex = (reel.comments || []).findIndex(c => c.id === commentId);

        if (commentIndex !== -1) {
            const comment = reel.comments[commentIndex];
            if (comment.userId === userId || reel.userId === userId || isAdmin(userId)) {
                reel.comments.splice(commentIndex, 1);
                storage.write('Reels', 'all', allReels);
                res.json({ success: true });
            } else {
                res.status(403).json({ error: 'Permission denied' });
            }
        } else {
            res.status(404).json({ error: 'Comment not found' });
        }
    } else {
        res.status(404).json({ error: 'Reel not found' });
    }
});

// --- SEARCH API ---
app.get('/api/search', (req, res) => {
    const { q, type = 'all', page = 1, limit = 20 } = req.query;
    if (!q) return res.json({ results: [] });

    const query = q.toLowerCase().trim();
    let results = [];

    // Helper for Arabic normalization
    const normalize = (text) => {
        if (!text) return '';
        return text.toLowerCase()
            .replace(/[أإآ]/g, 'ا')
            .replace(/ة/g, 'ه')
            .replace(/ى/g, 'ي')
            .trim();
    };

    const normalizedQuery = normalize(query);

    if (type === 'all' || type === 'students') {
        const students = Students.getAll()
            .filter(s => normalize(s.name).includes(normalizedQuery) || s.studentId.includes(query))
            .map(s => ({ ...s, resultType: 'student' }));
        results = results.concat(students);
    }

    if (type === 'all' || type === 'questions') {
        const questions = storage.readList('Questions', 'all')
            .filter(q => normalize(q.content).includes(normalizedQuery))
            .map(q => ({ ...q, resultType: 'question' }));
        results = results.concat(questions);
    }

    if (type === 'all' || type === 'reels') {
        const reels = storage.readList('Reels', 'all')
            .filter(r => normalize(r.title).includes(normalizedQuery) || normalize(r.caption).includes(normalizedQuery))
            .map(r => ({ ...r, resultType: 'reel' }));
        results = results.concat(reels);
    }

    if (type === 'all' || type === 'materials') {
        const materials = storage.readList('Materials', 'all')
            .filter(m => m.status === 'approved' && (normalize(m.title).includes(normalizedQuery) || normalize(m.subject_name).includes(normalizedQuery)))
            .map(m => ({ ...m, resultType: 'material' }));
        results = results.concat(materials);
    }

    const start = (page - 1) * limit;
    res.json({
        query: q,
        total: results.length,
        results: results.slice(start, start + parseInt(limit))
    });
});

// --- Aggregated Feed API ---
app.get('/api/feed', (req, res) => {
    const studentId = req.headers['x-student-id'];
    const { page = 1, limit = 20 } = req.query;

    if (!studentId) return res.status(400).json({ error: 'Missing student ID' });

    const student = Students.getById(studentId);
    if (!student) return res.status(404).json({ error: 'Student not found' });

    const following = student.following || [];

    // Combine questions and reels from followed users
    const questions = storage.readList('Questions', 'all')
        .filter(q => following.includes(q.userId))
        .map(q => ({ ...q, feedType: 'question' }));

    const reels = storage.readList('Reels', 'all')
        .filter(r => following.includes(r.userId))
        .map(r => ({ ...r, feedType: 'reel' }));

    let feed = [...questions, ...reels].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

    const start = (page - 1) * limit;
    res.json(feed.slice(start, start + parseInt(limit)));
});

// --- Reputation & Badges API ---
const Reputation = {
    add: (studentId, points, reason, type = 'generic') => {
        Points.add(studentId, points, reason);
        const log = {
            id: Date.now().toString(),
            studentId,
            points,
            reason,
            type,
            timestamp: new Date().toISOString()
        };
        storage.appendList('ReputationHistory', studentId, log);
        BadgeManager.check(studentId);
    }
};

const BadgeManager = {
    check: (studentId) => {
        const student = Students.getById(studentId);
        if (!student) return;

        const points = student.points || 0;
        const currentBadges = storage.readList('Badges', studentId) || [];
        const newBadges = [];

        const badgeDefinitions = [
            { id: 'newcomer', name: 'مبتدئ', minPoints: 100, icon: '🌟' },
            { id: 'active', name: 'نشط', minPoints: 500, icon: '🔥' },
            { id: 'expert', name: 'خبير', minPoints: 2000, icon: '💎' },
            { id: 'legend', name: 'أسطورة', minPoints: 10000, icon: '👑' }
        ];

        badgeDefinitions.forEach(b => {
            if (points >= b.minPoints && !currentBadges.find(cb => cb.id === b.id)) {
                const newBadge = { ...b, awardedAt: new Date().toISOString() };
                storage.appendList('Badges', studentId, newBadge);
                newBadges.push(newBadge);
            }
        });

        if (newBadges.length > 0) {
            newBadges.forEach(nb => {
                const notification = {
                    id: Date.now().toString(),
                    userId: studentId,
                    type: 'badge_awarded',
                    title: 'وسام جديد!',
                    body: `لقد حصلت على وسام: ${nb.name} ${nb.icon}`,
                    referenceId: nb.id,
                    isRead: false,
                    createdAt: new Date().toISOString()
                };
                storage.appendList('Notifications', studentId, notification);
                io.to(studentId).emit('new_notification', notification);
            });
        }
    }
};

app.get('/api/student/:id/badges', (req, res) => {
    res.json(storage.readList('Badges', req.params.id));
});

app.get('/api/student/:id/reputation', (req, res) => {
    res.json(storage.readList('ReputationHistory', req.params.id));
});

// --- Bookmarks API ---
app.post('/api/bookmarks/toggle', (req, res) => {
    const studentId = req.headers['x-student-id'];
    const { targetType, targetId } = req.body;

    if (!studentId || !targetType || !targetId) return res.status(400).json({ error: 'Missing data' });

    let bookmarks = storage.readList('Bookmarks', studentId);
    const existingIdx = bookmarks.findIndex(b => b.targetType === targetType && b.targetId === targetId);

    if (existingIdx !== -1) {
        bookmarks.splice(existingIdx, 1);
        storage.write('Bookmarks', studentId, bookmarks);
        return res.json({ bookmarked: false });
    } else {
        const bookmark = {
            id: Date.now().toString(),
            targetType,
            targetId,
            createdAt: new Date().toISOString()
        };
        storage.appendList('Bookmarks', studentId, bookmark);
        return res.json({ bookmarked: true, bookmark });
    }
});

app.get('/api/bookmarks', (req, res) => {
    const studentId = req.headers['x-student-id'];
    if (!studentId) return res.status(400).json({ error: 'Missing student ID' });
    const bookmarks = storage.readList('Bookmarks', studentId);

    // Enrich bookmarks with target data
    const enriched = bookmarks.map(b => {
        let data = null;
        if (b.targetType === 'question') {
            data = storage.readList('Questions', 'all').find(q => q.id === b.targetId);
            if (data) {
                const student = Students.getById(data.studentId);
                data = {
                    ...data,
                    studentName: student ? student.name : 'Unknown',
                    studentProfileImage: student ? student.profileImage : null
                };
            }
        } else if (b.targetType === 'reel') {
            data = storage.readList('Reels', 'all').find(r => r.id === b.targetId);
            if (data) {
                const student = Students.getById(data.userId);
                data = {
                    ...data,
                    creatorName: student ? student.name : 'Unknown',
                    creatorProfileImage: student ? student.profileImage : null
                };
            }
        } else if (b.targetType === 'material') {
            data = storage.readList('Materials', 'all').find(m => m.id === b.targetId);
        }
        return { ...b, data };
    }).filter(b => b.data !== null);

    res.json(enriched);
});

// --- LIBRARY / MATERIALS ENDPOINTS ---
app.get('/api/materials/specializations', (req, res) => {
    res.json(storage.readList('Library', 'specializations'));
});

app.get('/api/materials/levels/:specId', (req, res) => {
    const levels = storage.readList('Library', 'levels');
    res.json(levels.filter(l => l.specializationId == req.params.specId));
});

app.get('/api/materials/subjects', (req, res) => {
    const { levelId, semesterId } = req.query;
    const allSubjects = storage.readList('Library', 'subjects');
    res.json(allSubjects.filter(s => s.levelId == levelId && s.semesterId == semesterId));
});

app.get('/api/materials', (req, res) => {
    const { subjectId, type, page = 1, limit = 20, subjectName } = req.query;
    const requesterId = req.headers['x-student-id'];
    const all = storage.readList('Materials', 'all');

    // Public users see approved materials; the uploader can also see their
    // own pending submission while it is waiting for moderation.
    let filtered = all.filter(m =>
        m.status === 'approved' ||
        (requesterId && m.creator_id === requesterId)
    );

    if (subjectId && subjectId != '0') {
        filtered = filtered.filter(m => m.subjectId == subjectId);
    } else if (subjectName) {
        filtered = filtered.filter(m => m.subject_name === subjectName);
    }

    if (type) filtered = filtered.filter(m => m.material_type === type);

    const start = (page - 1) * limit;
    res.json(filtered.slice(start, parseInt(start) + parseInt(limit)));
});

app.post('/api/materials', (req, res) => {
    const studentId = req.headers['x-student-id'];
    if (!studentId) return res.status(400).json({ error: 'Missing student ID' });

    const student = Students.getById(studentId);
    if (!student) return res.status(404).json({ error: 'Student not found' });

    // Verify creator_id matches session if provided
    if (req.body.creator_id && req.body.creator_id !== studentId) {
        return res.status(403).json({ error: 'Unauthorized: Creator ID mismatch' });
    }

    // Server-side permission check
    const canUpload = isAdmin(studentId) ||
                      student.role === ROLES.TEACHER ||
                      student.role === ROLES.DOCTOR ||
                      (student.role === ROLES.MEMBER && (student.points || 0) >= 1000);

    if (!canUpload) {
        return res.status(403).json({ error: 'ليس لديك صلاحية لمشاركة الملخصات. يجب أن يكون لديك 1000 نقطة على الأقل.' });
    }

    const {
        specialization_name,
        level_name,
        subject_name,
        specialization_id,
        level_id,
        subject_id,
        file_url,
        ...rest
    } = req.body;

    const finalFileUrl = moveFileFromTemp(file_url, student.studentId);

    const material = {
        id: Date.now().toString(),
        ...rest,
        file_url: finalFileUrl,
        creator_id: student.studentId,
        creator_name: student.name,
        creator_role: student.role,
        specialization_name: specialization_name || `Spec-${specialization_id}`,
        level_name: level_name || `Level-${level_id}`,
        subject_name: subject_name || `Subject-${subject_id}`,
        specialization_id: specialization_id || 0,
        level_id: level_id || 0,
        subject_id: subject_id || 0,
        status: 'pending', // Default to pending for review
        views_count: 0,
        downloads_count: 0,
        created_at: new Date().toISOString()
    };
    storage.appendList('Materials', 'all', material);
    logger.success(`Material metadata saved: ${material.title} by ${studentId} (Pending approval)`);

    // Notify Admins about new pending material
    const notification = {
        id: Date.now().toString(),
        userId: 'ADMINS', // Special tag or loop through admins
        type: 'summary_pending',
        senderId: studentId,
        referenceId: material.id,
        title: 'طلب مراجعة ملخص جديد',
        body: `قام ${student.name} برفع ملخص جديد: ${material.title}`,
        isRead: false,
        createdAt: new Date().toISOString()
    };

    // Broadcast to all admins online
    Students.getAll().forEach(s => {
        if (s.role === ROLES.ADMIN || s.role === ROLES.ASSISTANT) {
            const adminNotify = { ...notification, userId: s.studentId };
            storage.appendList('Notifications', s.studentId, adminNotify);
            io.to(s.studentId).emit('new_notification', adminNotify);
        }
    });

    res.json({
        success: true,
        summaryId: material.id,
        status: material.status,
        message: 'Summary uploaded and awaiting approval'
    });
});

app.post('/api/materials/:id/view', (req, res) => {
    let all = storage.readList('Materials', 'all');
    const idx = all.findIndex(m => m.id === req.params.id);
    if (idx !== -1) {
        all[idx].views_count = (all[idx].views_count || 0) + 1;
        storage.write('Materials', 'all', all);
        res.json({ success: true });
    } else res.status(404).json({ error: 'Not found' });
});

app.post('/api/materials/:id/download', (req, res) => {
    let all = storage.readList('Materials', 'all');
    const idx = all.findIndex(m => m.id === req.params.id);
    if (idx !== -1) {
        all[idx].downloads_count = (all[idx].downloads_count || 0) + 1;
        storage.write('Materials', 'all', all);
        res.json({ success: true });
    } else res.status(404).json({ error: 'Not found' });
});

// --- ADMIN MATERIALS & REPORTS ---
app.get('/api/admin/materials/pending', (req, res) => {
    const adminId = req.headers['x-student-id'];
    if (!isAdmin(adminId)) return res.status(403).json({ error: 'Forbidden' });
    const all = storage.readList('Materials', 'all');
    res.json(all.filter(m => m.status === 'pending'));
});

app.post('/api/admin/materials/:id/status', (req, res) => {
    const adminId = req.headers['x-student-id'];
    if (!isAdmin(adminId)) return res.status(403).json({ error: 'Forbidden' });

    const { status, reason } = req.body;
    let all = storage.readList('Materials', 'all');
    const idx = all.findIndex(m => m.id === req.params.id);

    if (idx !== -1) {
        const oldStatus = all[idx].status;
        all[idx].status = status;
        all[idx].rejectionReason = reason;
        storage.write('Materials', 'all', all);
        AdminLogs.add(adminId, 'UPDATE_MATERIAL_STATUS', req.params.id, status);

        // Notify uploader about status change
        const uploaderId = all[idx].creator_id;
        if (uploaderId) {
            const statusAr = status === 'approved' ? 'مقبول' : (status === 'rejected' ? 'مرفوض' : status);
            const notification = {
                id: Date.now().toString(),
                userId: uploaderId,
                type: `summary_${status}`,
                senderId: adminId,
                referenceId: all[idx].id,
                title: status === 'approved' ? 'تم قبول ملخصك' : 'تم رفض ملخصك',
                body: status === 'approved'
                    ? `تهانينا! تم قبول ملخصك: ${all[idx].title}`
                    : `للأسف تم رفض ملخصك: ${all[idx].title}${reason ? '. السبب: ' + reason : ''}`,
                isRead: false,
                createdAt: new Date().toISOString()
            };
            storage.appendList('Notifications', uploaderId, notification);
            io.to(uploaderId).emit('new_notification', notification);

            // If approved, notify everyone (optional or just followers)
            if (status === 'approved') {
                io.emit('material_approved', all[idx]);
            }
        }

        res.json(all[idx]);
    } else res.status(404).json({ error: 'Not found' });
});

app.post('/api/admin/reports/:id/resolve', (req, res) => {
    const adminId = req.headers['x-student-id'];
    if (!isAdmin(adminId)) return res.status(403).json({ error: 'Forbidden' });
    const updated = Reports.updateStatus(req.params.id, 'resolved', adminId);
    res.json(updated);
});

app.delete('/api/admin/reports/:id/content', (req, res) => {
    const adminId = req.headers['x-student-id'];
    if (!isAdmin(adminId)) return res.status(403).json({ error: 'Forbidden' });

    const reportId = req.params.id;
    let reports = Reports.getAll();
    const report = reports.find(r => r.id === reportId);

    if (!report) return res.status(404).json({ error: 'Report not found' });

    const { targetType, targetId } = report;
    let deleted = false;

    try {
        if (targetType === 'question') {
            let allQ = storage.readList('Questions', 'all');
            const index = allQ.findIndex(q => q.id == targetId);
            if (index !== -1) {
                const question = allQ[index];
                allQ.splice(index, 1);
                storage.write('Questions', 'all', allQ);
                const answersPath = path.join(DATA_ROOT, 'Questions', `answers_${targetId}.json`);
                if (fs.existsSync(answersPath)) fs.unlinkSync(answersPath);
                io.emit('question_deleted', { questionId: targetId });
                deleted = true;
            }
        } else if (targetType === 'reel') {
            let allReels = storage.readList('Reels', 'all');
            const index = allReels.findIndex(r => r.id === targetId);
            if (index !== -1) {
                allReels.splice(index, 1);
                storage.write('Reels', 'all', allReels);
                deleted = true;
            }
        } else if (targetType === 'answer') {
            const questionsDir = path.join(DATA_ROOT, 'Questions');
            const files = fs.readdirSync(questionsDir);
            for (const file of files) {
                if (file.startsWith('answers_')) {
                    const qId = file.replace('answers_', '').replace('.json', '');
                    let answers = storage.readList('Questions', `answers_${qId}`);
                    const aIdx = answers.findIndex(a => a.id == targetId);
                    if (aIdx !== -1) {
                        const deletedAnswer = answers[aIdx];
                        answers.splice(aIdx, 1);
                        storage.write('Questions', `answers_${qId}`, answers);

                        let allQ = storage.readList('Questions', 'all');
                        const qIdx = allQ.findIndex(q => q.id == qId);
                        if (qIdx !== -1) {
                            allQ[qIdx].answerCount = Math.max(0, (allQ[qIdx].answerCount || 1) - 1);
                            storage.write('Questions', 'all', allQ);
                        }

                        let userAnswers = storage.readList('Answers', deletedAnswer.userId);
                        if (userAnswers) {
                            userAnswers = userAnswers.filter(a => a.id != targetId);
                            storage.write('Answers', deletedAnswer.userId, userAnswers);
                        }
                        deleted = true;
                        break;
                    }
                }
            }
        } else if (targetType === 'user') {
            if (isMainAdmin(adminId)) {
                deleted = Students.delete(targetId, adminId);
            }
        }
    } catch (e) {
        logger.error(`Error deleting reported content: ${e}`);
    }

    if (deleted) {
        Reports.updateStatus(reportId, 'resolved_with_deletion', adminId);
        AdminLogs.add(adminId, 'DELETE_REPORTED_CONTENT', targetId, `Type: ${targetType}`);
        res.json({ success: true });
    } else {
        res.status(404).json({ error: 'Content not found or already deleted' });
    }
});

app.get('/api/student/:studentId/answers', (req, res) => {
    res.json(storage.readList('Answers', req.params.studentId));
});

app.get('/api/chat/history/:targetId', (req, res) => {
    const myId = req.headers['x-student-id'];
    const targetId = req.params.targetId;
    if (!myId || !targetId) return res.status(400).json({ error: 'Missing IDs' });

    const pairId = [myId, targetId].sort().join('_');
    const history = storage.readList('Messages', pairId);
    res.json(history);
});

app.get('/api/leaderboard', (req, res) => {
    const board = Students.getAll()
        .sort((a, b) => (b.points || 0) - (a.points || 0))
        .slice(0, 50)
        .map(s => ({
            ...s,
            online: activeUsers.has(s.studentId)
        }));
    res.json(board);
});

// --- Socket.IO Real-time Logic ---
const io3000 = new Server(server3000, { cors: { origin: "*" } });
const io3001 = new Server(server3001, { cors: { origin: "*" } });
const io3002 = new Server(server3002, { cors: { origin: "*" } });
const allIOs = [io3000, io3001, io3002];

// Proxy 'io' to broadcast across all port instances
const io = {
    emit: (event, data) => allIOs.forEach(i => i.emit(event, data)),
    to: (room) => ({
        emit: (event, data) => allIOs.forEach(i => i.to(room).emit(event, data))
    }),
    sockets: {
        sockets: {
            get: (id) => {
                for (const i of allIOs) {
                    const s = i.sockets.sockets.get(id);
                    if (s) return s;
                }
                return null;
            }
        }
    }
};

const activeUsers = new Map(); // studentId -> Set of socketIds

allIOs.forEach(instance => {
    instance.on('connection', (socket) => {
    const studentId = socket.handshake.query.studentId;
    if (!studentId || studentId === 'unknown') return socket.disconnect();

    socket.join(studentId);
    if (!activeUsers.has(studentId)) activeUsers.set(studentId, new Set());
    activeUsers.get(studentId).add(socket.id);

    logger.success(`Student connected: ${studentId}`);
    io.emit('status', { studentId, online: true });

    socket.on('send_message', async (data) => {
        const { targetId, text, type, mediaUrl, messageId: clientMsgId } = data;
        logger.info(`[CHAT-IN] From: ${studentId} To: ${targetId} | MsgId: ${clientMsgId} | Type: ${type}`);

        // التحقق من صلاحية الجلسة
        if (!studentId || !targetId) {
            logger.warn(`[CHAT-REJECT] Missing sender (${studentId}) or target (${targetId})`);
            return;
        }

        const message = {
            id: Date.now().toString(),
            clientMsgId: clientMsgId || Date.now().toString(),
            senderId: studentId,
            receiverId: targetId,
            text,
            type: type || 'text',
            mediaUrl: mediaUrl || null,
            status: 'sent', // sent, delivered, read
            timestamp: new Date().toISOString()
        };

        // إنشاء معرف محادثة فريد
        const pairId = [studentId, targetId].sort().join('_');

        // حفظ الرسالة
        storage.appendList('Messages', pairId, message);

        // Notify Receiver
        const notification = {
            id: Date.now().toString(),
            userId: targetId,
            type: 'message',
            senderId: studentId,
            senderName: Students.getById(studentId)?.name || 'Someone',
            referenceId: pairId,
            title: 'رسالة جديدة',
            body: type === 'text' ? text : `أرسل لك ${type === 'image' ? 'صورة' : 'ملفاً'}`,
            isRead: false,
            createdAt: new Date().toISOString()
        };
        storage.appendList('Notifications', targetId, notification);

        // التحقق من حالة المستلم
        const targetSockets = activeUsers.get(targetId);
        if (targetSockets && targetSockets.size > 0) {
            // المستلم متصل
            logger.info(`[CHAT-DELIVER] Delivering to online user ${targetId} (${targetSockets.size} sockets)`);
            io.to(targetId).emit('receive_message', message);
            io.to(targetId).emit('new_notification', notification);
        } else {
            // المستلم غير متصل
            logger.info(`[CHAT-QUEUE] User ${targetId} offline, queuing message`);
            storage.appendList('PendingMessages', targetId, message);
        }

        const newTotal = Points.add(studentId, 1, 'إرسال رسالة');
        io.to(studentId).emit('update_points', { points: newTotal });
    });

    // عند قراءة الرسالة
    socket.on('mark_read', (data) => {
        const { senderId, clientMsgId } = data;
        const pairId = [studentId, senderId].sort().join('_');
        let chatHistory = storage.readList('Messages', pairId);

        const msgIndex = chatHistory.findIndex(m => m.clientMsgId === clientMsgId);
        if (msgIndex !== -1) {
            chatHistory[msgIndex].status = 'read';
            storage.write('Messages', pairId, chatHistory);

            // إبلاغ المرسل الأصلي أن رسالته قُرأت
            io.to(senderId).emit('message_status', { clientMsgId, status: 'read' });
        }
    });

    // استلام الإشعارات غير المقروءة عند العودة للاتصال
    socket.on('get_notifications', () => {
        const notifications = storage.readList('Notifications', studentId);
        socket.emit('notifications_list', notifications);
    });

    socket.on('mark_notification_read', (notifId) => {
        let notifications = storage.readList('Notifications', studentId);
        const idx = notifications.findIndex(n => n.id === notifId);
        if (idx !== -1) {
            notifications[idx].isRead = true;
            storage.write('Notifications', studentId, notifications);
        }
    });

    // استلام الرسائل المعلقة عند العودة للاتصال
    socket.on('get_pending_messages', () => {
        let pending = storage.readList('PendingMessages', studentId);
        if (pending.length > 0) {
            logger.info(`[CHAT] Delivering ${pending.length} pending messages to ${studentId}`);
            pending.forEach(msg => {
                socket.emit('receive_message', msg);
                // إبلاغ المرسل بالوصول
                io.to(msg.senderId).emit('message_status', { clientMsgId: msg.clientMsgId, status: 'delivered' });

                // تحديث حالة الرسالة في مخزن الرسائل الرئيسي أيضاً
                const pairId = [msg.senderId, msg.receiverId].sort().join('_');
                let chatHistory = storage.readList('Messages', pairId);
                const msgIndex = chatHistory.findIndex(m => m.clientMsgId === msg.clientMsgId);
                if (msgIndex !== -1 && chatHistory[msgIndex].status === 'sent') {
                    chatHistory[msgIndex].status = 'delivered';
                    storage.write('Messages', pairId, chatHistory);
                }
            });            // تفريغ قائمة الانتظار بعد التسليم
            storage.write('PendingMessages', studentId, []);
        } else {
            logger.info(`[CHAT] No pending messages for ${studentId}`);
        }
    });

    socket.on('typing_start', (data) => {
        socket.to(data.targetId).emit('typing_status', { senderId: studentId, status: 'typing' });
    });

    socket.on('typing_stop', (data) => {
        socket.to(data.targetId).emit('typing_status', { senderId: studentId, status: 'idle' });
    });

    socket.on('recording_start', (data) => {
        socket.to(data.targetId).emit('typing_status', { senderId: studentId, status: 'recording' });
    });

    socket.on('recording_stop', (data) => {
        socket.to(data.targetId).emit('typing_status', { senderId: studentId, status: 'idle' });
    });

    socket.on('post_question', async (data) => {
        const { content, mediaUrls, userId } = data;

        const senderId = userId || studentId;
        const finalMediaUrls = (mediaUrls || []).map(url => moveFileFromTemp(url, senderId));

        const question = {
            id: Date.now(),
            userId: senderId,
            content: content,
            mediaUrls: finalMediaUrls,
            timestamp: new Date().toISOString(),
            points: 5,
            answerCount: 0
        };
        storage.appendList('Questions', 'all', question);
        const newTotal = Points.add(question.userId, 5, 'Asked a question');

        io.emit('new_question', question);
        io.to(question.userId).emit('update_points', { points: newTotal });
    });

    socket.on('post_answer', (data) => {
        const senderId = data.userId || studentId;
        const finalMediaUrls = (data.mediaUrls || (data.mediaUrl ? [data.mediaUrl] : [])).map(url => moveFileFromTemp(url, senderId));

        const answer = {
            id: Date.now().toString(),
            questionId: data.questionId.toString(),
            userId: senderId,
            content: data.content,
            mediaUrls: finalMediaUrls,
            mediaType: data.mediaType,
            timestamp: new Date().toISOString(),
            isBest: false,
            votes: [] // Array of studentIds who voted
        };
        storage.appendList('Questions', `answers_${data.questionId}`, answer);

        // Also add to global answers list for the user
        storage.appendList('Answers', answer.userId, answer);

        let allQ = storage.readList('Questions', 'all');
        const qIdx = allQ.findIndex(q => q.id.toString() == data.questionId.toString());
        if (qIdx !== -1) {
            allQ[qIdx].answerCount = (allQ[qIdx].answerCount || 0) + 1;
            storage.write('Questions', 'all', allQ);

            // Notify question owner
            const questionOwner = allQ[qIdx].userId;
            if (questionOwner !== answer.userId) {
                const notification = {
                    id: Date.now().toString(),
                    userId: questionOwner,
                    type: 'new_answer',
                    senderId: answer.userId,
                    senderName: Students.getById(answer.userId)?.name || 'Someone',
                    referenceId: data.questionId.toString(),
                    title: 'إجابة جديدة',
                    body: `قام ${Students.getById(answer.userId)?.name || 'مستخدم'} بالرد على سؤالك`,
                    isRead: false,
                    createdAt: new Date().toISOString()
                };
                storage.appendList('Notifications', questionOwner, notification);
                io.to(questionOwner).emit('new_notification', notification);
            }
        }

        const newTotal = Points.add(answer.userId, 10, 'Answered a question');
        io.emit('new_answer', answer);
        io.to(answer.userId).emit('update_points', { points: newTotal });
    });

    socket.on('edit_answer', (data) => {
        const { questionId, answerId, content, mediaUrls, mediaType } = data;
        let answers = storage.readList('Questions', `answers_${questionId}`);
        const idx = answers.findIndex(a => a.id.toString() === answerId.toString());

        if (idx !== -1 && (answers[idx].userId === studentId || isAdmin(studentId))) {
            const senderId = answers[idx].userId;
            answers[idx].content = content;
            if (mediaUrls) {
                answers[idx].mediaUrls = mediaUrls.map(url => moveFileFromTemp(url, senderId));
            }
            if (mediaType) answers[idx].mediaType = mediaType;
            answers[idx].editedAt = new Date().toISOString();
            storage.write('Questions', `answers_${questionId}`, answers);

            // Update user's personal answers list
            let userAnswers = storage.readList('Answers', answers[idx].userId);
            const uIdx = userAnswers.findIndex(a => a.id.toString() === answerId.toString());
            if (uIdx !== -1) {
                userAnswers[uIdx] = { ...userAnswers[uIdx], ...answers[idx] };
                storage.write('Answers', answers[idx].userId, userAnswers);
            }

            io.emit('answer_updated', answers[idx]);
        }
    });

    socket.on('delete_answer', (data) => {
        const { questionId, answerId } = data;
        let answers = storage.readList('Questions', `answers_${questionId}`);
        const idx = answers.findIndex(a => a.id.toString() === answerId.toString());

        if (idx !== -1) {
            const answer = answers[idx];
            if (answer.userId === studentId || isAdmin(studentId)) {
                answers.splice(idx, 1);
                storage.write('Questions', `answers_${questionId}`, answers);

                // Update question answer count
                let allQ = storage.readList('Questions', 'all');
                const qIdx = allQ.findIndex(q => q.id.toString() == questionId.toString());
                if (qIdx !== -1) {
                    allQ[qIdx].answerCount = Math.max(0, (allQ[qIdx].answerCount || 1) - 1);
                    storage.write('Questions', 'all', allQ);
                }

                // Update user's personal answers list
                let userAnswers = storage.readList('Answers', answer.userId);
                userAnswers = userAnswers.filter(a => a.id.toString() !== answerId.toString());
                storage.write('Answers', answer.userId, userAnswers);

                io.emit('answer_deleted', { questionId, answerId });
            }
        }
    });

    socket.on('vote_question', (data) => {
        const { questionId } = data;
        let allQ = storage.readList('Questions', 'all');
        const idx = allQ.findIndex(q => q.id.toString() == questionId.toString());

        if (idx !== -1) {
            if (!allQ[idx].votes) allQ[idx].votes = [];
            const voteIdx = allQ[idx].votes.indexOf(studentId);

            if (voteIdx === -1) {
                allQ[idx].votes.push(studentId);
            } else {
                allQ[idx].votes.splice(voteIdx, 1);
            }

            allQ[idx].points = allQ[idx].votes.length;
            storage.write('Questions', 'all', allQ);
            io.emit('question_voted', { questionId, points: allQ[idx].points, votes: allQ[idx].votes });
        }
    });

    socket.on('vote_answer', (data) => {
        const { questionId, answerId } = data;
        let answers = storage.readList('Questions', `answers_${questionId}`);
        const idx = answers.findIndex(a => a.id.toString() === answerId.toString());

        if (idx !== -1) {
            if (!answers[idx].votes) answers[idx].votes = [];
            const voteIdx = answers[idx].votes.indexOf(studentId);

            if (voteIdx === -1) {
                answers[idx].votes.push(studentId);
            } else {
                answers[idx].votes.splice(voteIdx, 1);
            }

            storage.write('Questions', `answers_${questionId}`, answers);
            io.emit('answer_voted', { questionId, answerId, votes: answers[idx].votes });
        }
    });

    socket.on('mark_best_answer', (data) => {
        const { questionId, answerId } = data;
        let allQ = storage.readList('Questions', 'all');
        const qIdx = allQ.findIndex(q => q.id.toString() == questionId.toString());

        if (qIdx !== -1 && allQ[qIdx].userId === studentId) {
            let answers = storage.readList('Questions', `answers_${questionId}`);

            // Reset all isBest first
            answers.forEach(a => a.isBest = false);

            const ansIdx = answers.findIndex(a => a.id.toString() === answerId.toString());

            if (ansIdx !== -1) {
                answers[ansIdx].isBest = true;
                storage.write('Questions', `answers_${questionId}`, answers);

                // Update Question model if it tracks bestAnswerId
                allQ[qIdx].bestAnswerId = answerId.toString();
                storage.write('Questions', 'all', allQ);

                const winnerPoints = Points.add(answers[ansIdx].userId, 50, 'Best Answer Reward');
                io.to(answers[ansIdx].userId).emit('update_points', { points: winnerPoints });
                io.emit('best_answer_marked', { questionId, answerId });
            }
        }
    });

    socket.on('delete_question', (data) => {
        const { questionId } = data;
        let allQ = storage.readList('Questions', 'all');
        const questionIndex = allQ.findIndex(q => q.id == questionId);

        if (questionIndex !== -1) {
            const question = allQ[questionIndex];
            const canDelete = question.userId === studentId || checkPermission(studentId, 'delete_questions');

            if (canDelete) {
                allQ.splice(questionIndex, 1);
                storage.write('Questions', 'all', allQ);

                if (question.userId !== studentId) {
                    AdminLogs.add(studentId, 'DELETE_QUESTION', questionId, `Deleted question by ${question.userId}`);
                }

                // Remove answers file
                const answersPath = path.join(DATA_ROOT, 'Questions', `answers_${questionId}.json`);
                if (fs.existsSync(answersPath)) fs.unlinkSync(answersPath);

                io.emit('question_deleted', { questionId });
                logger.info(`Question deleted: ${questionId} by ${studentId}`);
            }
        }
    });

    socket.on('typing', (data) => {
        socket.to(data.targetId).emit('typing', { studentId, isTyping: data.isTyping });
    });

    socket.on('get_leaderboard', () => {
        const board = Students.getAll()
            .sort((a, b) => (b.points || 0) - (a.points || 0))
            .slice(0, 50)
            .map(s => ({
                ...s,
                online: activeUsers.has(s.studentId)
            }));
        socket.emit('leaderboard', board);
    });

    socket.on('message_received_ack', (data) => {
        const { clientMsgId, senderId } = data;
        logger.info(`[CHAT-ACK] From: ${studentId} (receiver) For: ${clientMsgId} SentBy: ${senderId}`);
        const pairId = [studentId, senderId].sort().join('_');
        let chatHistory = storage.readList('Messages', pairId);
        const msgIndex = chatHistory.findIndex(m => m.clientMsgId === clientMsgId);
        if (msgIndex !== -1 && chatHistory[msgIndex].status === 'sent') {
            chatHistory[msgIndex].status = 'delivered';
            storage.write('Messages', pairId, chatHistory);
            logger.info(`[CHAT-STATUS-UPDATE] Updated ${clientMsgId} to delivered in storage`);
        }
        io.to(senderId).emit('message_status', { clientMsgId, status: 'delivered' });
    });

    socket.on('get_chat_history', (data) => {
        const pairId = [studentId, data.targetId].sort().join('_');
        const history = storage.readList('Messages', pairId);
        socket.emit('chat_history', { targetId: data.targetId, history });
    });

    socket.on('unban_member', (data) => {
        const adminId = studentId;
        const { targetId } = data;
        if (!checkPermission(adminId, 'unban_members')) return;

        const updated = Students.unban(targetId, adminId);
        if (updated) {
            io.to(targetId).emit('unbanned');
            logger.info(`User unbanned: ${targetId} by ${adminId}`);
        }
    });

    socket.on('signaling', (data) => {
        const { targetId, type } = data;
        io.to(targetId).emit('signaling', { ...data, senderId: studentId });

        // If it's a new call offer, send a notification
        if (type === 'offer') {
            const sender = Students.getById(studentId);
            const callType = data.callType === 'video' ? 'فيديو' : 'صوتية';
            const notification = {
                id: Date.now().toString(),
                userId: targetId,
                type: data.callType === 'video' ? 'video_call' : 'audio_call',
                senderId: studentId,
                senderName: sender?.name || 'Someone',
                referenceId: studentId,
                title: `مكالمة ${callType} واردة`,
                body: `${sender?.name || 'مستخدم'} يتصل بك...`,
                isRead: false,
                createdAt: new Date().toISOString()
            };
            // Do not store call notifications in DB as they are transient
            io.to(targetId).emit('new_notification', notification);
        }
    });

    socket.on('disconnect', () => {
        const sockets = activeUsers.get(studentId);
        if (sockets) {
            sockets.delete(socket.id);
            if (sockets.size === 0) {
                activeUsers.delete(studentId);
                io.emit('status', { studentId, online: false });

                const student = Students.getById(studentId);
                if (student) {
                    student.lastSeen = new Date().toISOString();
                    Students.update(student);
                }
            }
        }
    });
});
});

server3000.listen(PORT_MAIN, '0.0.0.0', () => logger.success(`Main Server (API/Chat) running on port ${PORT_MAIN}`));
server3001.listen(PORT_MEDIA, '0.0.0.0', () => logger.success(`Media Socket Server running on port ${PORT_MEDIA}`));
server3002.listen(PORT_CALL, '0.0.0.0', () => logger.success(`Call/Audio Socket Server running on port ${PORT_CALL}`));

// Start Cleanup Task (Runs every 24 hours)
setInterval(cleanupTask, 24 * 60 * 60 * 1000);
// Run once on startup after 1 minute
setTimeout(cleanupTask, 60 * 1000);

function cleanupTask() {
    logger.info('Running background cleanup task...');
    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));

    // 1. Prune Notifications
    // ... (rest of the code)
}

function orphanedFileCleanup() {
    logger.info('Running orphaned file cleanup...');
    const referencedFiles = new Set();

    // Collect all referenced files from DBs
    // Questions
    const questions = storage.readList('Questions', 'all');
    questions.forEach(q => {
        if (q.mediaUrls) q.mediaUrls.forEach(url => referencedFiles.add(path.basename(url)));
    });

    // Answers
    const questionsDir = path.join(DATA_ROOT, 'Questions');
    if (fs.existsSync(questionsDir)) {
        fs.readdirSync(questionsDir).forEach(file => {
            if (file.startsWith('answers_')) {
                const answers = storage.read(questionsDir, file.replace('.json', ''));
                if (answers) answers.forEach(a => {
                    if (a.mediaUrls) a.mediaUrls.forEach(url => referencedFiles.add(path.basename(url)));
                });
            }
        });
    }

    // Reels
    const reels = storage.readList('Reels', 'all');
    reels.forEach(r => {
        if (r.videoUrl) referencedFiles.add(path.basename(r.videoUrl));
        if (r.thumbnail) referencedFiles.add(path.basename(r.thumbnail));
    });

    // Materials
    const materials = storage.readList('Materials', 'all');
    materials.forEach(m => {
        if (m.file_url) referencedFiles.add(path.basename(m.file_url));
    });

    // Students
    const students = Students.getAll();
    students.forEach(s => {
        if (s.profileImage) referencedFiles.add(path.basename(s.profileImage));
        if (s.backgroundImage) referencedFiles.add(path.basename(s.backgroundImage));
    });

    // Scan actual files and delete orphans
    const uploadsDir = path.join(DATA_ROOT, 'Uploads');
    ['Images', 'Audio', 'Files'].forEach(sub => {
        const subDir = path.join(uploadsDir, sub);
        if (fs.existsSync(subDir)) {
            const studentDirs = fs.readdirSync(subDir);
            studentDirs.forEach(sDir => {
                const fullPath = path.join(subDir, sDir);
                if (fs.statSync(fullPath).isDirectory()) {
                    const files = fs.readdirSync(fullPath);
                    files.forEach(file => {
                        if (!referencedFiles.has(file)) {
                            // Extra check: make sure it's not a very recent file (avoid race conditions)
                            const filePath = path.join(fullPath, file);
                            const stats = fs.statSync(filePath);
                            const ageInHours = (Date.now() - stats.mtimeMs) / (1000 * 60 * 60);

                            if (ageInHours > 24) { // Give it 24 hours to be claimed
                                fs.unlinkSync(filePath);
                                logger.info(`Deleted orphaned file: ${filePath}`);
                            }
                        }
                    });
                }
            });
        }
    });
}