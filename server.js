// Add this after middleware setup

// Fixed Admin Credentials
const FIXED_ADMINS = [
    {
        id: 'admin_001',
        name: 'System Administrator',
        email: 'admin@smartparenting.com',
        password: '$2a$10$N9qo8uLOickgx2ZMRZoMyeAJs2ZfZ6M.9pzY7b8pQ.7qWk2pN9QaC', // Hash of 'admin123'
        role: 'admin',
        isActive: true,
        isVerified: true,
        isBlocked: false
    }
];

// Check if email is admin email
function isAdminEmail(email) {
    return FIXED_ADMINS.some(admin => admin.email === email);
}

// Admin login endpoint (fixed credentials)
app.post('/api/admin/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        
        // Check if it's admin email
        if (!isAdminEmail(email)) {
            return res.status(401).json({ error: 'Invalid admin credentials' });
        }
        
        // Find admin
        const admin = FIXED_ADMINS.find(a => a.email === email);
        
        // Verify password
        const validPassword = await bcrypt.compare(password, admin.password);
        if (!validPassword) {
            return res.status(401).json({ error: 'Invalid admin credentials' });
        }
        
        // Create JWT token
        const token = jwt.sign(
            { 
                id: admin.id, 
                email: admin.email, 
                role: admin.role,
                name: admin.name,
                isFixedAdmin: true 
            },
            JWT_SECRET,
            { expiresIn: '7d' }
        );
        
        // Remove password from response
        const { password: _, ...adminWithoutPassword } = admin;
        
        res.json({
            token,
            user: adminWithoutPassword,
            message: 'Admin login successful'
        });
        
    } catch (error) {
        console.error('Admin login error:', error);
        res.status(500).json({ error: 'Server error during admin login' });
    }
});

// Regular login endpoint (for non-admin users)
app.post('/api/login', async (req, res) => {
    try {
        const { email, phone, password } = req.body;
        
        // Prevent admin login through regular endpoint
        if (email && isAdminEmail(email)) {
            return res.status(401).json({ 
                error: 'Admin must login through admin portal' 
            });
        }
        
        // Find user by email or phone
        const user = db.users.find(u => 
            (email && u.email === email) || 
            (phone && u.phone === phone)
        );
        
        if (!user) {
            return res.status(401).json({ 
                error: 'User not found. Please register first.' 
            });
        }
        
        // Check if user is verified (for experts)
        if (user.role === 'expert' && !user.isVerified) {
            return res.status(403).json({ 
                error: 'Your expert account is pending verification by admin.' 
            });
        }
        
        // Check if user is blocked
        if (user.isBlocked) {
            return res.status(403).json({ 
                error: 'Account is blocked. Please contact admin.' 
            });
        }
        
        // Check if user is active
        if (!user.isActive) {
            return res.status(403).json({ 
                error: 'Account is deactivated.' 
            });
        }
        
        // Verify password
        const validPassword = await bcrypt.compare(password, user.password);
        if (!validPassword) {
            return res.status(401).json({ error: 'Invalid password' });
        }
        
        // Create JWT token
        const token = jwt.sign(
            { 
                id: user.id, 
                email: user.email, 
                role: user.role,
                name: user.name 
            },
            JWT_SECRET,
            { expiresIn: '7d' }
        );
        
        // Remove password from response
        const { password: _, ...userWithoutPassword } = user;
        
        // Update last login
        user.lastLogin = new Date().toISOString();
        saveDB();
        
        res.json({
            token,
            user: userWithoutPassword,
            message: 'Login successful'
        });
        
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Server error during login' });
    }
});

// Registration endpoint (Prevent admin registration)
app.post('/api/register', async (req, res) => {
    try {
        const { name, email, phone, password, role, gender, address, dateOfBirth, expertInfo } = req.body;
        
        // Prevent admin registration
        if (role === 'admin') {
            return res.status(403).json({ 
                error: 'Admin registration is not allowed' 
            });
        }
        
        // Check if trying to register with admin email
        if (isAdminEmail(email)) {
            return res.status(403).json({ 
                error: 'This email is reserved for system admin' 
            });
        }
        
        // Validation
        if (!name || !email || !phone || !password || !role) {
            return res.status(400).json({ 
                error: 'All required fields must be filled' 
            });
        }
        
        // Email validation
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            return res.status(400).json({ 
                error: 'Please enter a valid email address' 
            });
        }
        
        // Password validation
        if (password.length < 6) {
            return res.status(400).json({ 
                error: 'Password must be at least 6 characters' 
            });
        }
        
        // Phone validation
        const phoneRegex = /^\+?[1-9]\d{1,14}$/;
        if (!phoneRegex.test(phone.replace(/\D/g, ''))) {
            return res.status(400).json({ 
                error: 'Please enter a valid phone number' 
            });
        }
        
        // Check if user already exists
        const existingEmail = db.users.find(u => u.email === email);
        if (existingEmail) {
            return res.status(400).json({ 
                error: 'User with this email already exists' 
            });
        }
        
        const existingPhone = db.users.find(u => u.phone === phone);
        if (existingPhone) {
            return res.status(400).json({ 
                error: 'User with this phone number already exists' 
            });
        }
        
        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);
        
        // Create user object
        const user = {
            id: 'user_' + Date.now(),
            name,
            email,
            phone,
            password: hashedPassword,
            role,
            gender,
            address,
            dateOfBirth,
            expertInfo: role === 'expert' ? expertInfo : null,
            profilePhoto: null,
            isActive: true,
            isVerified: role !== 'expert', // Experts need admin verification
            isBlocked: false,
            lastLogin: null,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        };
        
        // Save user
        db.users.push(user);
        saveDB();
        
        // Create JWT token
        const token = jwt.sign(
            { id: user.id, email: user.email, role: user.role },
            JWT_SECRET,
            { expiresIn: '7d' }
        );
        
        // Remove password from response
        const { password: _, ...userWithoutPassword } = user;
        
        res.status(201).json({
            message: 'Registration successful. Please login.',
            user: userWithoutPassword
        });
        
    } catch (error) {
        console.error('Registration error:', error);
        res.status(500).json({ error: 'Server error during registration' });
    }
});

// Add endpoint to check if email is available
app.get('/api/check-email/:email', (req, res) => {
    try {
        const { email } = req.params;
        
        // Check if email is admin email
        if (isAdminEmail(email)) {
            return res.json({ available: false, message: 'Email reserved for admin' });
        }
        
        const exists = db.users.some(u => u.email === email);
        res.json({ available: !exists });
        
    } catch (error) {
        console.error('Check email error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// Add endpoint to check if phone is available
app.get('/api/check-phone/:phone', (req, res) => {
    try {
        const { phone } = req.params;
        const exists = db.users.some(u => u.phone === phone);
        res.json({ available: !exists });
        
    } catch (error) {
        console.error('Check phone error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});