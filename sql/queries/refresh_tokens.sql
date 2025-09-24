-- name: CreateRefreshToken :one
INSERT INTO refresh_tokens (token, created_at, updated_at, user_id, expires_at, revoked_at)
VALUES (
    $1,
    NOW(),
    NOW(),
    $2,
    $3,
    NULL
)
RETURNING *;

-- name: GetRefreshToken :one
SELECT token, created_at, updated_at, user_id, expires_at, revoked_at
FROM refresh_tokens
WHERE token = $1;

-- name: GetUserFromRefreshToken :one
SELECT
    u.id AS user_id,
    u.created_at AS user_created_at,
    u.updated_at AS user_updated_at,
    u.email AS user_email,
    u.hashed_password AS user_hashed_password,
    r.token,
    r.created_at,
    r.updated_at,
    r.expires_at,
    r.revoked_at
FROM refresh_tokens r
JOIN users u ON u.id = r.user_id
WHERE r.token = $1;

-- name: RevokeRefreshToken :exec
UPDATE refresh_tokens
SET revoked_at = NOW(),
    updated_at = NOW()
WHERE token = $1;
