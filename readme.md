# GoTrue on PostgreSQL

> GoTrue is a small open-source API written in golang, that can act as a self-standing
> API service for handling user registration and authentication for JAM projects.

GoTrue uses MySQL as storage, but if your architecture already uses PostgreSQL it might
make sense convert its schema.

```bash
# launch a multipass vm with ubuntu
multipass launch --name gotrue bionic

# perform build steps
cat build.sh | multipass shell gotrue
```

The build first initializes the MySQL version of the database and starts a migration.
Once this is done the [pgloader](https://pgloader.io/) tooling is used to convert the database to PostgreSQL.
Some columns use varchars for uuids so we convert these into the native `uuid` type.
Use the `GOTRUE_SMTP_*` and `MAILER_AUTOCONFIRM` environment variables to enable email.

Note that JWT can be used and configured in ways that defeats it's security features:
- [No Way, JOSE! Javascript Object Signing and Encryption is a Bad Standard That Everyone Should Avoid](https://paragonie.com/blog/2017/03/jwt-json-web-tokens-is-bad-standard-that-everyone-should-avoid)

## CLI Admin

```bash
# enter the vm
multipass shell gotrue

# open database
export DATABASE_URL=postgres://gotrue:weceekae5iequiquiy9E@localhost/gotrue
psql $DATABASE_URL

# dump database
pg_dump $DATABASE_URL >gotrue.sql
```

- [gotrue.sql](gotrue.sql)

## User Signup

```bash
export EMAIL=user@domain.com
export PASSWORD=pa2ay4deit9uDo4ishoh
http http://localhost:8081/signup email=$EMAIL password=$PASSWORD
```

```json
{
    "app_metadata": {
        "provider": "email"
    },
    "aud": "netlify",
    "confirmation_sent_at": "2020-05-23T16:03:16.80003666+02:00",
    "created_at": "2020-05-23T16:03:16.798961+02:00",
    "email": "user@domain.com",
    "id": "7653e392-07e9-4351-9eef-844a92a5f605",
    "role": "",
    "updated_at": "2020-05-23T16:03:16.800121+02:00",
    "user_metadata": null
}
```

## Verify

```bash
# fetch confirmation from the db because we disabled email
psql $DATABASE_URL -c "select confirmation_token from users where email='$EMAIL'"

   confirmation_token
------------------------
 hV7N5KaOMuieu0Gsp66TQA
(1 row)


# verify
http http://localhost:8081/verify type=signup token=hV7N5KaOMuieu0Gsp66TQA
```

```json
{
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJuZXRsaWZ5IiwiZXhwIjoxNTkwNTkxMjU5LCJzdWIiOiI4ZmQwYmUxZC0yY2YxLTQ1ZTQtOTRlNi04NjcwY2M3NjFjNDEiLCJlbWFpbCI6InVzZXJAZG9tYWluLmNvbSIsImFwcF9tZXRhZGF0YSI6eyJwcm92aWRlciI6ImVtYWlsIn0sInVzZXJfbWV0YWRhdGEiOnt9fQ.jPIPO-YgBzMwLL-ex5w-8JU9am3IDI6k01uhbtNH0ck",
    "expires_in": 3600,
    "refresh_token": "o3Xv1DEUuVqaQXMKH8A_Lg",
    "token_type": "bearer"
}
```

## Refresh

```bash
http POST 'http://localhost:8081/token?grant_type=refresh_token&refresh_token=o3Xv1DEUuVqaQXMKH8A_Lg'
```

```json
{
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJuZXRsaWZ5IiwiZXhwIjoxNTkwNTkxNDEzLCJzdWIiOiI4ZmQwYmUxZC0yY2YxLTQ1ZTQtOTRlNi04NjcwY2M3NjFjNDEiLCJlbWFpbCI6InVzZXJAZG9tYWluLmNvbSIsImFwcF9tZXRhZGF0YSI6eyJwcm92aWRlciI6ImVtYWlsIn0sInVzZXJfbWV0YWRhdGEiOnt9fQ.BdUZazs_nAQfTMcWSXen2wEBtLZzpLVQxVCwiMJ8MM0",
    "expires_in": 3600,
    "refresh_token": "WfgZsd21P_Gi49JAaXh_lg",
    "token_type": "bearer"
}
```

## Fetch User

```
http GET http://localhost:8081/user "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJuZXRsaWZ5IiwiZXhwIjoxNTkwNTkxNDEzLCJzdWIiOiI4ZmQwYmUxZC0yY2YxLTQ1ZTQtOTRlNi04NjcwY2M3NjFjNDEiLCJlbWFpbCI6InVzZXJAZG9tYWluLmNvbSIsImFwcF9tZXRhZGF0YSI6eyJwcm92aWRlciI6ImVtYWlsIn0sInVzZXJfbWV0YWRhdGEiOnt9fQ.BdUZazs_nAQfTMcWSXen2wEBtLZzpLVQxVCwiMJ8MM0"
```

```json
{
    "app_metadata": {
        "provider": "email"
    },
    "aud": "netlify",
    "confirmation_sent_at": "2020-05-27T15:31:44.680935+02:00",
    "confirmed_at": "2020-05-27T15:54:19.549863+02:00",
    "created_at": "2020-05-27T15:31:44.680144+02:00",
    "email": "user@domain.com",
    "id": "8fd0be1d-2cf1-45e4-94e6-8670cc761c41",
    "role": "",
    "updated_at": "2020-05-27T15:31:44.680148+02:00",
    "user_metadata": {}
}
```

## Update `user_metadata`

Warning: JWT tokens are http headers and their size should be kept to a minimum.

```
echo '{
    "data":{
        "key": "value",
        "number": 10,
        "admin": false
    }
}' | http PUT http://localhost:8081/user "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJuZXRsaWZ5IiwiZXhwIjoxNTkwNTkxNDEzLCJzdWIiOiI4ZmQwYmUxZC0yY2YxLTQ1ZTQtOTRlNi04NjcwY2M3NjFjNDEiLCJlbWFpbCI6InVzZXJAZG9tYWluLmNvbSIsImFwcF9tZXRhZGF0YSI6eyJwcm92aWRlciI6ImVtYWlsIn0sInVzZXJfbWV0YWRhdGEiOnt9fQ.BdUZazs_nAQfTMcWSXen2wEBtLZzpLVQxVCwiMJ8MM0"
```

```json
{
    "app_metadata": {
        "provider": "email"
    },
    "aud": "netlify",
    "confirmation_sent_at": "2020-05-27T15:31:44.680935+02:00",
    "confirmed_at": "2020-05-27T15:54:19.549863+02:00",
    "created_at": "2020-05-27T15:31:44.680144+02:00",
    "email": "user@domain.com",
    "id": "8fd0be1d-2cf1-45e4-94e6-8670cc761c41",
    "role": "",
    "updated_at": "2020-05-27T16:00:03.296752+02:00",
    "user_metadata": {
        "admin": false,
        "key": "value",
        "number": 10
    }
}
```

## Logout

```bash
$DATABASE_URL -c "select * from refresh_tokens" -P pager
# two refresh tokens are there (one active and one revoked)

http POST http://localhost:8081/logout "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJuZXRsaWZ5IiwiZXhwIjoxNTkwNTkxNDEzLCJzdWIiOiI4ZmQwYmUxZC0yY2YxLTQ1ZTQtOTRlNi04NjcwY2M3NjFjNDEiLCJlbWFpbCI6InVzZXJAZG9tYWluLmNvbSIsImFwcF9tZXRhZGF0YSI6eyJwcm92aWRlciI6ImVtYWlsIn0sInVzZXJfbWV0YWRhdGEiOnt9fQ.BdUZazs_nAQfTMcWSXen2wEBtLZzpLVQxVCwiMJ8MM0"

psql $DATABASE_URL -c "select * from refresh_tokens" -P pager
(0 rows)
```

## Login

```
http POST "http://localhost:8081/token?grant_type=password&username=$EMAIL&password=$PASSWORD"
```

```json
{
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJuZXRsaWZ5IiwiZXhwIjoxNTkwNTkyMDEzLCJzdWIiOiI4ZmQwYmUxZC0yY2YxLTQ1ZTQtOTRlNi04NjcwY2M3NjFjNDEiLCJlbWFpbCI6InVzZXJAZG9tYWluLmNvbSIsImFwcF9tZXRhZGF0YSI6eyJwcm92aWRlciI6ImVtYWlsIn0sInVzZXJfbWV0YWRhdGEiOnsiYWRtaW4iOmZhbHNlLCJrZXkiOiJ2YWx1ZSIsIm51bWJlciI6MTB9fQ.uBEhxR-v4bs9Jad2LCYV9ANXh9WoCYrHsiE3O4Y50Wo",
    "expires_in": 3600,
    "refresh_token": "n21iFhMqbwO-I7DeNMR5OA",
    "token_type": "bearer"
}
```

## Create Admin User (for /admin/* endpoints)

```bash
# create an admin user that can access to the /admin/* endpoints
gotrue admin createuser -i 00000000-0000-0000-0000-000000000000 admin@domain.com pa2ay4deit9uDo4ishoh --admin --confirm
```

```bash
export AUTH=`http POST 'http://localhost:8081/token?grant_type=password&username=admin@domain.com&password=pa2ay4deit9uDo4ishoh'`
export ACCESS_TOKEN=`echo $AUTH | jq .access_token -r`
echo $ACCESS_TOKEN

# list users
http GET http://localhost:8081/admin/users "Authorization: Bearer $ACCESS_TOKEN"
```

## Update `app_metadata`

```bash
echo '{
    "app_metadata": {
        "role": "important"
    }
}' | http PUT http://localhost:8081/admin/users/8fd0be1d-2cf1-45e4-94e6-8670cc761c41 "Authorization: Bearer $ACCESS_TOKEN"
```

```json
{
    "app_metadata": {
        "provider": "email",
        "role": "important"
    },
    "aud": "netlify",
    "confirmation_sent_at": "2020-05-27T15:31:44.680935+02:00",
    "confirmed_at": "2020-05-27T15:54:19.549863+02:00",
    "created_at": "2020-05-27T15:31:44.680144+02:00",
    "email": "user@domain.com",
    "id": "8fd0be1d-2cf1-45e4-94e6-8670cc761c41",
    "role": "",
    "updated_at": "2020-05-27T16:11:25.517373+02:00",
    "user_metadata": {
        "admin": false,
        "key": "value",
        "number": 10
    }
}
```

## References

- [GoTrue](https://github.com/netlify/gotrue)
- [GoTrue Configuration](https://github.com/netlify/gotrue#configuration)
- [GoTrue Endpoints](https://github.com/netlify/gotrue#endpoints)
