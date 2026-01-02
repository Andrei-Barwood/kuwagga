// Firebase Integration - Anonymous Posting Enabled
let currentUser = null;
let anonymousUsername = null;

// Check auth state
firebase.auth().onAuthStateChanged((user) => {
    if (user) {
        currentUser = user;
        anonymousUsername = null;
        showUserMenu(user);
    } else {
        currentUser = null;
        // Get or create anonymous username
        anonymousUsername = localStorage.getItem('anonymousUsername');
        if (!anonymousUsername) {
            promptForUsername();
        }
        hideUserMenu();
    }
    
    loadPosts();
});

// Prompt for anonymous username (first time only)
function promptForUsername() {
    const username = prompt('Choose a username for this session:\n(Your posts will be anonymous unless you create an account)', 'Anonymous');
    if (username && username.trim()) {
        anonymousUsername = username.trim();
        localStorage.setItem('anonymousUsername', anonymousUsername);
    } else {
        anonymousUsername = 'Anonymous';
        localStorage.setItem('anonymousUsername', 'Anonymous');
    }
}

// Show/Hide User Menu
function showUserMenu(user) {
    const userMenu = document.getElementById('userMenu');
    const userName = document.getElementById('userName');
    const userAvatar = document.getElementById('userAvatar');
    
    if (userMenu && userName && userAvatar) {
        userMenu.style.display = 'flex';
        userName.textContent = user.displayName || user.email.split('@')[0];
        userAvatar.src = user.photoURL || 'dj-photo.jpg';
    }
    
    // Update post composer to show they're posting as verified user
    updateComposerStatus(true);
}

function hideUserMenu() {
    const userMenu = document.getElementById('userMenu');
    if (userMenu) {
        userMenu.style.display = 'none';
    }
    
    // Update post composer to show anonymous posting
    updateComposerStatus(false);
}

// Update composer to show posting status
function updateComposerStatus(isAuthenticated) {
    const composer = document.querySelector('.post-composer');
    if (!composer) return;
    
    // Remove existing status if any
    const existingStatus = composer.querySelector('.composer-status');
    if (existingStatus) existingStatus.remove();
    
    // Add status indicator
    const status = document.createElement('div');
    status.className = 'composer-status';
    
    if (isAuthenticated) {
        status.innerHTML = `
            <span class="status-badge verified">✓ Posting as ${currentUser.displayName || currentUser.email.split('@')[0]}</span>
            <button class="btn-small" id="logoutBtn2">Logout</button>
        `;
        document.getElementById('logoutBtn2')?.addEventListener('click', () => firebase.auth().signOut());
    } else {
        status.innerHTML = `
            <span class="status-badge anonymous">👤 Posting as ${anonymousUsername}</span>
            <button class="btn-small" id="changeUsernameBtn">Change Name</button>
            <button class="btn-small" id="createAccountBtn">Create Account (Get Notified)</button>
        `;
        
        document.getElementById('changeUsernameBtn')?.addEventListener('click', () => {
            localStorage.removeItem('anonymousUsername');
            promptForUsername();
            updateComposerStatus(false);
        });
        
        document.getElementById('createAccountBtn')?.addEventListener('click', () => {
            document.getElementById('authModal').classList.add('active');
        });
    }
    
    composer.insertBefore(status, composer.firstChild);
}

// Auth Modal Controls
document.getElementById('closeAuthModal')?.addEventListener('click', () => {
    document.getElementById('authModal').classList.remove('active');
});

document.getElementById('showRegister')?.addEventListener('click', (e) => {
    e.preventDefault();
    document.getElementById('loginForm').style.display = 'none';
    document.getElementById('registerForm').style.display = 'block';
});

document.getElementById('showLogin')?.addEventListener('click', (e) => {
    e.preventDefault();
    document.getElementById('registerForm').style.display = 'none';
    document.getElementById('loginForm').style.display = 'block';
});

// Register
document.getElementById('registerBtn')?.addEventListener('click', async () => {
    const username = document.getElementById('registerUsername').value;
    const email = document.getElementById('registerEmail').value;
    const password = document.getElementById('registerPassword').value;

    if (!username || !email || !password) {
        showError('Please fill all fields');
        return;
    }

    if (password.length < 6) {
        showError('Password must be at least 6 characters');
        return;
    }

    try {
        const userCredential = await firebase.auth().createUserWithEmailAndPassword(email, password);
        await userCredential.user.updateProfile({ displayName: username });
        
        // Create user document with email notification preference
        await db.collection('users').doc(userCredential.user.uid).set({
            username: username,
            email: email,
            emailNotifications: true,
            createdAt: firebase.firestore.FieldValue.serverTimestamp(),
            previousAnonymousUsername: anonymousUsername // Track their anonymous name
        });
        
        // Optionally claim their anonymous posts
        await claimAnonymousPosts(anonymousUsername, userCredential.user.uid, username);
        
        hideError();
        document.getElementById('authModal').classList.remove('active');
        alert(`✅ Account created! You'll now get email notifications when the community posts.`);
    } catch (error) {
        showError(error.message);
    }
});

// Login
document.getElementById('loginBtn')?.addEventListener('click', async () => {
    const email = document.getElementById('loginEmail').value;
    const password = document.getElementById('loginPassword').value;

    if (!email || !password) {
        showError('Please fill all fields');
        return;
    }

    try {
        await firebase.auth().signInWithEmailAndPassword(email, password);
        hideError();
        document.getElementById('authModal').classList.remove('active');
    } catch (error) {
        showError(error.message);
    }
});

// Logout
document.getElementById('logoutBtn')?.addEventListener('click', async () => {
    if (confirm('Logout? You can still post anonymously.')) {
        await firebase.auth().signOut();
    }
});

// Claim anonymous posts when creating account
async function claimAnonymousPosts(anonymousName, userId, newUsername) {
    try {
        const postsSnapshot = await db.collection('posts')
            .where('username', '==', anonymousName)
            .where('isAnonymous', '==', true)
            .get();
        
        const batch = db.batch();
        postsSnapshot.forEach(doc => {
            batch.update(doc.ref, {
                userId: userId,
                username: newUsername,
                isAnonymous: false,
                claimedAt: firebase.firestore.FieldValue.serverTimestamp()
            });
        });
        
        await batch.commit();
        console.log(`✅ Claimed ${postsSnapshot.size} anonymous posts`);
    } catch (error) {
        console.error('Error claiming posts:', error);
    }
}

// Error handling
function showError(message) {
    const errorDiv = document.getElementById('authError');
    if (errorDiv) {
        errorDiv.textContent = message;
        errorDiv.classList.add('active');
    }
}

function hideError() {
    const errorDiv = document.getElementById('authError');
    if (errorDiv) {
        errorDiv.classList.remove('active');
    }
}

// ===== POSTS FUNCTIONALITY =====

// Create Post (Anonymous OR Authenticated)
document.addEventListener('click', function(e) {
    if (e.target.id === 'postBtn' || e.target.closest('#postBtn')) {
        handlePostCreation();
    }
});

async function handlePostCreation() {
    const postInput = document.getElementById('postInput');
    const content = postInput.value.trim();
    if (!content) return;

    const tags = content.match(/#\w+/g) || [];
    
    // Determine who's posting
    const isAnonymous = !currentUser;
    const posterUsername = isAnonymous ? anonymousUsername : (currentUser.displayName || currentUser.email.split('@')[0]);
    const posterId = isAnonymous ? null : currentUser.uid;
    
    try {
        // Add to Firestore
        const postData = {
            userId: posterId,
            username: posterUsername,
            userAvatar: isAnonymous ? 'dj-photo.jpg' : (currentUser.photoURL || 'dj-photo.jpg'),
            content: content,
            tags: tags,
            category: 'thoughts',
            likes: 0,
            replies: 0,
            shares: 0,
            likedBy: [],
            isAnonymous: isAnonymous,
            createdAt: firebase.firestore.FieldValue.serverTimestamp()
        };
        
        await db.collection('posts').add(postData);

        // Send email notifications to subscribed users ONLY
        if (!isAnonymous || true) { // Send for all posts
            await sendEmailNotifications(content, posterUsername);
        }

        // Clear input
        postInput.value = '';
        const charCount = document.getElementById('charCount');
        if (charCount) charCount.textContent = '0/500';
        
        // Show success message
        showSuccessMessage('✅ Posted to the community!');
        
    } catch (error) {
        console.error('Error creating post:', error);
        alert('Failed to create post. Please try again.');
    }
}

// Success message
function showSuccessMessage(message) {
    const existing = document.querySelector('.success-toast');
    if (existing) existing.remove();
    
    const toast = document.createElement('div');
    toast.className = 'success-toast';
    toast.textContent = message;
    document.body.appendChild(toast);
    
    setTimeout(() => toast.classList.add('show'), 10);
    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// Load Posts from Firestore (Real-time)
function loadPosts() {
    const postsFeed = document.getElementById('postsFeed');
    
    db.collection('posts')
        .orderBy('createdAt', 'desc')
        .limit(50)
        .onSnapshot((snapshot) => {
            postsFeed.innerHTML = '';
            
            snapshot.forEach((doc) => {
                const post = doc.data();
                const postId = doc.id;
                createPostElement(post, postId);
            });
        });
}

// Create Post Element
function createPostElement(post, postId) {
    const postsFeed = document.getElementById('postsFeed');
    const article = document.createElement('article');
    article.className = 'feed-post';
    article.setAttribute('data-category', post.category || 'thoughts');
    article.setAttribute('data-post-id', postId);

    const timeAgo = getTimeAgo(post.createdAt);
    const contentWithoutTags = post.content.replace(/#\w+/g, '').trim();
    
    // Check if current user liked this
    const userId = currentUser ? currentUser.uid : `anon_${anonymousUsername}`;
    const localLikes = JSON.parse(localStorage.getItem('likedPosts') || '[]');
    const isLiked = currentUser 
        ? (post.likedBy && post.likedBy.includes(currentUser.uid))
        : localLikes.includes(postId);

    // Anonymous badge
    const anonymousBadge = post.isAnonymous 
        ? '<span class="anonymous-badge" title="Anonymous post">👤</span>' 
        : '';

    article.innerHTML = `
        <div class="post-avatar">
            <img src="${post.userAvatar || 'dj-photo.jpg'}" alt="${post.username}">
        </div>
        <div class="post-content">
            <div class="post-header">
                <div class="post-author">
                    <span class="author-name">${post.username}</span>
                    ${anonymousBadge}
                    <span class="author-handle">@${post.username.toLowerCase().replace(/\s/g, '')}</span>
                    <span class="post-badge">${post.category || 'Thoughts'}</span>
                </div>
                <span class="post-time">${timeAgo}</span>
            </div>
            <div class="post-body">
                <p>${contentWithoutTags}</p>
                ${post.tags && post.tags.length > 0 ? `
                    <div class="post-tags">
                        ${post.tags.map(tag => `<span class="post-tag">${tag}</span>`).join('')}
                    </div>
                ` : ''}
            </div>
            <div class="post-footer">
                <button class="post-action like-btn ${isLiked ? 'active' : ''}" data-post-id="${postId}">
                    <span class="action-icon">♥</span>
                    <span class="action-count">${post.likes || 0}</span>
                </button>
                <button class="post-action reply-btn">
                    <span class="action-icon">💬</span>
                    <span class="action-count">${post.replies || 0}</span>
                </button>
                <button class="post-action share-btn">
                    <span class="action-icon">↗</span>
                    <span class="action-count">${post.shares || 0}</span>
                </button>
            </div>
        </div>
    `;

    postsFeed.appendChild(article);
    attachPostListeners(article, postId);
}

// Like Post (Works for everyone)
async function likePost(postId, likeBtn) {
    const postRef = db.collection('posts').doc(postId);
    const isLiked = likeBtn.classList.contains('active');
    
    // Track likes in localStorage for anonymous users
    const localLikes = JSON.parse(localStorage.getItem('likedPosts') || '[]');

    try {
        if (currentUser) {
            // Authenticated user - track in database
            if (isLiked) {
                await postRef.update({
                    likes: firebase.firestore.FieldValue.increment(-1),
                    likedBy: firebase.firestore.FieldValue.arrayRemove(currentUser.uid)
                });
            } else {
                await postRef.update({
                    likes: firebase.firestore.FieldValue.increment(1),
                    likedBy: firebase.firestore.FieldValue.arrayUnion(currentUser.uid)
                });
            }
        } else {
            // Anonymous user - track in localStorage
            if (isLiked) {
                await postRef.update({
                    likes: firebase.firestore.FieldValue.increment(-1)
                });
                const index = localLikes.indexOf(postId);
                if (index > -1) localLikes.splice(index, 1);
            } else {
                await postRef.update({
                    likes: firebase.firestore.FieldValue.increment(1)
                });
                localLikes.push(postId);
            }
            localStorage.setItem('likedPosts', JSON.stringify(localLikes));
        }
        
        // Update UI
        likeBtn.classList.toggle('active');
        const countSpan = likeBtn.querySelector('.action-count');
        const currentCount = parseInt(countSpan.textContent);
        countSpan.textContent = isLiked ? currentCount - 1 : currentCount + 1;
        
    } catch (error) {
        console.error('Error liking post:', error);
    }
}

// Share Post
async function sharePost(postId, shareBtn) {
    const postRef = db.collection('posts').doc(postId);
    
    try {
        await postRef.update({
            shares: firebase.firestore.FieldValue.increment(1)
        });
        
        const postElement = document.querySelector(`[data-post-id="${postId}"]`);
        const content = postElement.querySelector('.post-body p').textContent;
        await navigator.clipboard.writeText(`"${content}" - Underground Community Feed\n${window.location.href}`);
        
        showSuccessMessage('✅ Post copied to clipboard!');
        
        const countSpan = shareBtn.querySelector('.action-count');
        countSpan.textContent = parseInt(countSpan.textContent) + 1;
    } catch (error) {
        console.error('Error sharing post:', error);
    }
}

// Attach Listeners
function attachPostListeners(postElement, postId) {
    const likeBtn = postElement.querySelector('.like-btn');
    const shareBtn = postElement.querySelector('.share-btn');

    likeBtn.addEventListener('click', () => likePost(postId, likeBtn));
    shareBtn.addEventListener('click', () => sharePost(postId, shareBtn));
}

// Time Ago Helper
function getTimeAgo(timestamp) {
    if (!timestamp) return 'Just now';
    
    const now = Date.now();
    const postTime = timestamp.toDate().getTime();
    const diff = Math.floor((now - postTime) / 1000);

    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
    return timestamp.toDate().toLocaleDateString();
}

// ===== EMAIL NOTIFICATIONS =====

async function sendEmailNotifications(postContent, authorName) {
    try {
        const usersSnapshot = await db.collection('users')
            .where('emailNotifications', '==', true)
            .get();
        
        if (usersSnapshot.empty) {
            console.log('No users subscribed to notifications');
            return;
        }

        const emails = [];
        usersSnapshot.forEach(doc => {
            const userData = doc.data();
            if (userData.email) {
                emails.push(userData.email);
            }
        });

        console.log(`📧 Would notify ${emails.length} subscribers about post by ${authorName}`);
        
        // TODO: Integrate with EmailJS or your email service
        // See previous implementation for EmailJS setup
        
    } catch (error) {
        console.error('Error sending notifications:', error);
    }
}

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
    // Check if username is set
    if (!firebase.auth().currentUser && !localStorage.getItem('anonymousUsername')) {
        promptForUsername();
    }
});
