-- Create blogs table
CREATE TABLE IF NOT EXISTS blogs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  content TEXT NOT NULL,
  summary TEXT NOT NULL,
  featured_image TEXT,
  author UUID REFERENCES auth.users(id),
  author_name TEXT NOT NULL,
  category TEXT NOT NULL,
  keywords TEXT[],
  read_time INTEGER NOT NULL,
  published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create index on slug for faster lookups
CREATE INDEX IF NOT EXISTS blogs_slug_idx ON blogs(slug);

-- Create index on category for filtering
CREATE INDEX IF NOT EXISTS blogs_category_idx ON blogs(category);

-- Set up RLS (Row Level Security)
ALTER TABLE blogs ENABLE ROW LEVEL SECURITY;

-- Create policy for reading (anyone can read)
CREATE POLICY blogs_select_policy ON blogs
  FOR SELECT USING (true);

-- Create policy for inserting (only authenticated users)
CREATE POLICY blogs_insert_policy ON blogs
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = author);

-- Create policy for updating (only author can update)
CREATE POLICY blogs_update_policy ON blogs
  FOR UPDATE TO authenticated USING (auth.uid() = author) WITH CHECK (auth.uid() = author);

-- Create policy for deleting (only author can delete)
CREATE POLICY blogs_delete_policy ON blogs
  FOR DELETE TO authenticated USING (auth.uid() = author);

-- Add function to update updated_at on updates
CREATE OR REPLACE FUNCTION update_blog_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
CREATE TRIGGER blogs_updated_at_trigger
BEFORE UPDATE ON blogs
FOR EACH ROW
EXECUTE FUNCTION update_blog_updated_at();
