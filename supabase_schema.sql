-- Enable the UUID extension
create extension if not exists "uuid-ossp";

-- 1. Create tables (if they don't exist)
create table if not exists profiles (
  id uuid references auth.users not null primary key,
  email text,
  username text,
  avatar_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists posts (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references profiles(id) not null,
  content text,
  image_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists comments (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references profiles(id) not null,
  post_id uuid references posts(id) on delete cascade not null,
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table if not exists likes (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references profiles(id) not null,
  post_id uuid references posts(id) on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, post_id)
);

-- 5. Row Level Security (RLS)
alter table profiles enable row level security;
alter table posts enable row level security;
alter table comments enable row level security;
alter table likes enable row level security;

-- Policies (Drop first to avoid "already exists" errors)
drop policy if exists "Public profiles are viewable by everyone" on profiles;
drop policy if exists "Users can insert their own profile" on profiles;
drop policy if exists "Users can update own profile" on profiles;

drop policy if exists "Anyone can read posts" on posts;
drop policy if exists "Authenticated users can create posts" on posts;
drop policy if exists "Users can delete their own posts" on posts;

drop policy if exists "Anyone can read comments" on comments;
drop policy if exists "Authenticated users can create comments" on comments;

drop policy if exists "Anyone can read likes" on likes;
drop policy if exists "Authenticated users can toggle likes" on likes;
drop policy if exists "Users can remove their own likes" on likes;

-- Re-create Policies
create policy "Public profiles are viewable by everyone" on profiles for select using (true);
create policy "Users can insert their own profile" on profiles for insert with check (auth.uid() = id);
create policy "Users can update own profile" on profiles for update using (auth.uid() = id);

create policy "Anyone can read posts" on posts for select using (true);
create policy "Authenticated users can create posts" on posts for insert with check (auth.role() = 'authenticated');
create policy "Users can delete their own posts" on posts for delete using (auth.uid() = user_id);

create policy "Anyone can read comments" on comments for select using (true);
create policy "Authenticated users can create comments" on comments for insert with check (auth.role() = 'authenticated');

create policy "Anyone can read likes" on likes for select using (true);
create policy "Authenticated users can toggle likes" on likes for insert with check (auth.role() = 'authenticated');
create policy "Users can remove their own likes" on likes for delete using (auth.uid() = user_id);

-- 6. AUTOMATIC PROFILE CREATION TRIGGER
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.profiles (id, email, username, avatar_url)
  values (new.id, new.email, new.raw_user_meta_data->>'username', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;

-- Drop trigger if exists to prevent duplicates
drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
