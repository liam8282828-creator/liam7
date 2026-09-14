# Supabase setup

## 1. Create the project

Create a project at https://supabase.com and copy:

- Project URL
- Publishable/anon key

Put them in `SupabaseConfiguration.moonPlace` in `ThreeOneOSFive/helpers/KeyAuthConfiguration.swift`.

Never put the `service_role` key in Swift, GitHub, or the IPA.

## 2. Create the database

Open Supabase SQL Editor and run `supabase/schema.sql`.

It creates `profiles` and `licenses`, enables RLS, and creates this test license:

```text
MOON-TEST-2026
```

## 3. Deploy the function

Install the Supabase CLI, log in, link the project, and run:

```text
supabase functions deploy moon-auth --no-verify-jwt
```

The function uses the built-in Supabase secrets `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`. Do not copy those secrets into the repository.

## 4. Test in the app

Register with:

```text
Username: moon
Password: moon123
License: MOON-TEST-2026
Phone: 5551234567
```

Then log in with the same username, password, and license. The function rejects expired, inactive, already-claimed, and unknown licenses.

## 5. Verify the response

A successful request returns HTTP 200 with a Supabase access token and expiration data. The app stores only the access token in Keychain. HTTP 400 means invalid input, 401 means account/login failure, 403 means license failure, and 409 means the username or license is already used.
