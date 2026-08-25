select
  id,
  email,
  email_confirmed_at,
  created_at
from auth.users
where lower(email) = 'admin@veera.local';
