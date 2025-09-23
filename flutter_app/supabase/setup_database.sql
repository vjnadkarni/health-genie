-- Galeno Genie Database Setup for Supabase
-- Run this SQL in your Supabase SQL Editor

-- Create user_profiles table to store user metadata
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  device_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create health_scores table to store calculated health scores
CREATE TABLE IF NOT EXISTS public.health_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  overall_score NUMERIC(5,2),
  cardiovascular_score NUMERIC(5,2),
  sleep_score NUMERIC(5,2),
  activity_score NUMERIC(5,2),
  recovery_score NUMERIC(5,2),
  stress_score NUMERIC(5,2),
  confidence_level NUMERIC(3,2),
  device_id TEXT,
  sync_source TEXT DEFAULT 'mobile',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create biometric_summaries table (store aggregated data, not raw biometrics)
CREATE TABLE IF NOT EXISTS public.biometric_summaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,

  -- Daily aggregates
  avg_heart_rate NUMERIC(5,2),
  min_heart_rate NUMERIC(5,2),
  max_heart_rate NUMERIC(5,2),
  avg_hrv NUMERIC(5,2),
  avg_blood_oxygen NUMERIC(5,2),

  -- Activity totals
  total_steps INTEGER,
  total_distance NUMERIC(10,2),
  active_energy_burned NUMERIC(10,2),

  -- Sleep summary
  total_sleep_minutes INTEGER,
  deep_sleep_minutes INTEGER,
  rem_sleep_minutes INTEGER,
  light_sleep_minutes INTEGER,
  awake_minutes INTEGER,

  device_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Ensure one summary per user per day
  UNIQUE(user_id, date)
);

-- Create indices for better performance
CREATE INDEX IF NOT EXISTS idx_health_scores_user_timestamp
  ON public.health_scores(user_id, timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_biometric_summaries_user_date
  ON public.biometric_summaries(user_id, date DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biometric_summaries ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies

-- User profiles: Users can only see and edit their own profile
CREATE POLICY "Users can view own profile"
  ON public.user_profiles
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.user_profiles
  FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.user_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Health scores: Users can only see and insert their own scores
CREATE POLICY "Users can view own health scores"
  ON public.health_scores
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own health scores"
  ON public.health_scores
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own health scores"
  ON public.health_scores
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own health scores"
  ON public.health_scores
  FOR DELETE
  USING (auth.uid() = user_id);

-- Biometric summaries: Users can only see and manage their own data
CREATE POLICY "Users can view own biometric summaries"
  ON public.biometric_summaries
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own biometric summaries"
  ON public.biometric_summaries
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own biometric summaries"
  ON public.biometric_summaries
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own biometric summaries"
  ON public.biometric_summaries
  FOR DELETE
  USING (auth.uid() = user_id);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers to auto-update timestamps
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_biometric_summaries_updated_at
  BEFORE UPDATE ON public.biometric_summaries
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

COMMENT ON TABLE public.health_scores IS 'Stores calculated health scores for cross-device sync';
COMMENT ON TABLE public.biometric_summaries IS 'Stores daily aggregated biometric data';
COMMENT ON TABLE public.user_profiles IS 'User profile information';