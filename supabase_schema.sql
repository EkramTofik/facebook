-- Enable the UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. PROFILES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id          UUID PRIMARY KEY,
    username    TEXT UNIQUE NOT NULL,
    full_name   TEXT,
    avatar_url  TEXT,
    cover_url   TEXT,
    bio         TEXT DEFAULT '',
    location    TEXT DEFAULT '',
    email       TEXT,
    verified    BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Ensure mock data can be inserted by dropping the strict auth.users constraint if it exists from previous runs
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- ============================================
-- 2. POSTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.posts (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content     TEXT,
    image_url   TEXT,
    visibility  TEXT NOT NULL DEFAULT 'public',
    created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================
-- 3. REACTIONS TABLE (Replaces simple likes)
-- ============================================
CREATE TABLE IF NOT EXISTS public.reactions (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    post_id       UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    reaction_type TEXT NOT NULL CHECK (reaction_type IN (
        'like', 'love', 'haha', 'wow', 'sad', 'angry'
    )),
    created_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE(user_id, post_id)
);

-- ============================================
-- 4. COMMENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.comments (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id     UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    author_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    parent_id   UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    content     TEXT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================
-- 5. STORIES TABLE (24h expiration)
-- ============================================
CREATE TABLE IF NOT EXISTS public.stories (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content     TEXT DEFAULT '',
    image_url   TEXT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    expires_at  TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours') NOT NULL
);

-- ============================================
-- 6. FRIENDS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.friends (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    friend_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status      TEXT NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'accepted', 'rejected', 'blocked')),
    created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE(user_id, friend_id),
    CONSTRAINT no_self_friendship CHECK (user_id != friend_id)
);

-- ============================================
-- 7. NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    sender_id   UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    type        TEXT NOT NULL CHECK (type IN ('like', 'comment', 'friend_request', 'post')),
    content     TEXT NOT NULL,
    related_id  UUID, -- post_id or comment_id or friend_request_id
    is_read     BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================
-- 8. ENABLE RLS
-- ============================================
ALTER TABLE public.profiles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stories   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friends   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 9. POLICIES
-- ============================================

-- Notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = recipient_id);
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = recipient_id);

-- Profiles
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);
DROP POLICY IF EXISTS "Own profile full access" ON public.profiles;
CREATE POLICY "Own profile full access" ON public.profiles FOR ALL USING (auth.uid() = id);

-- Posts
DROP POLICY IF EXISTS "Anyone can read posts" ON public.posts;
CREATE POLICY "Anyone can read posts" ON public.posts FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated users can create posts" ON public.posts;
CREATE POLICY "Authenticated users can create posts" ON public.posts FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Users can delete their own posts" ON public.posts;
CREATE POLICY "Users can delete their own posts" ON public.posts FOR DELETE USING (auth.uid() = author_id);
DROP POLICY IF EXISTS "Users can update their own posts" ON public.posts;
CREATE POLICY "Users can update their own posts" ON public.posts FOR UPDATE USING (auth.uid() = author_id);

-- Reactions
DROP POLICY IF EXISTS "Reactions visible to all" ON public.reactions;
CREATE POLICY "Reactions visible to all" ON public.reactions FOR SELECT USING (true);
DROP POLICY IF EXISTS "Users can manage own reactions" ON public.reactions;
CREATE POLICY "Users can manage own reactions" ON public.reactions FOR ALL USING (auth.uid() = user_id);

-- Comments
DROP POLICY IF EXISTS "Comments visible to all" ON public.comments;
CREATE POLICY "Comments visible to all" ON public.comments FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated can comment" ON public.comments;
CREATE POLICY "Authenticated can comment" ON public.comments FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Users can delete own comments" ON public.comments;
CREATE POLICY "Users can delete own comments" ON public.comments FOR DELETE USING (auth.uid() = author_id);

-- Stories
DROP POLICY IF EXISTS "Visible non-expired stories" ON public.stories;
CREATE POLICY "Visible non-expired stories" ON public.stories FOR SELECT USING (expires_at > NOW());
DROP POLICY IF EXISTS "Own stories full access" ON public.stories;
CREATE POLICY "Own stories full access" ON public.stories FOR ALL USING (auth.uid() = author_id);

-- Friends
DROP POLICY IF EXISTS "Own friendships" ON public.friends;
CREATE POLICY "Own friendships" ON public.friends FOR ALL USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- ============================================
-- 10. TRIGGER: Auto-create profile
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, username, avatar_url)
  VALUES (
    NEW.id, 
    NEW.email, 
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)), 
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ============================================
-- 12. SYNC EXISTING USERS
-- ============================================
-- Ensure any existing users have profiles (fixes FK errors if app was run before triggers)
INSERT INTO public.profiles (id, email, username)
SELECT id, email, COALESCE(raw_user_meta_data->>'username', split_part(email, '@', 1))
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 11. MOCK DATA
-- ============================================
-- 1. Create Mock Profiles
INSERT INTO public.profiles (id, username, full_name, avatar_url, bio, location)
VALUES 
('d1a2b3c4-e5f6-7a8b-9c0d-1e2f3a4b5c6d', 'john_doe', 'John Doe', 'https://i.pravatar.cc/150?img=1', 'Flutter Developer & Tech Enthusiast', 'New York, USA'),
('a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d', 'sarah_smith', 'Sarah Smith', 'https://i.pravatar.cc/150?img=5', 'Traveler | Foodie | Life seeker', 'London, UK'),
('b1c2d3e4-f5a6-7b8c-9d0e-1f2a3b4c5d6e', 'mike_williams', 'Mike Williams', 'https://i.pravatar.cc/150?img=8', 'Photography is my passion.', 'Toronto, Canada')
ON CONFLICT (id) DO NOTHING;

-- 2. Create Mock Posts
INSERT INTO public.posts (author_id, content, image_url, visibility)
VALUES 
('d1a2b3c4-e5f6-7a8b-9c0d-1e2f3a4b5c6d', 'Just finished building this Facebook clone! What do you think?', 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97', 'public'),
('a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d', 'Enjoying a beautiful sunset in London today. #blessed', 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad', 'public');

-- ============================================
-- 10. INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_posts_author_created     ON public.posts(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reactions_post           ON public.reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_created    ON public.comments(post_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_stories_author_expires   ON public.stories(author_id, expires_at);
CREATE INDEX IF NOT EXISTS idx_friends_status_users     ON public.friends(status, user_id, friend_id);

-- ============================================
-- 11. RPC: Get post stats
-- ============================================
CREATE OR REPLACE FUNCTION get_post_stats(p_post_id UUID)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'reaction_count', (SELECT COUNT(*) FROM public.reactions WHERE post_id = p_post_id),
        'my_reaction', (
            SELECT reaction_type 
            FROM public.reactions 
            WHERE post_id = p_post_id AND user_id = auth.uid()
            LIMIT 1
        ),
        'comments_count', (SELECT COUNT(*) FROM public.comments WHERE post_id = p_post_id)
    ) INTO result;
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
