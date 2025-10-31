insert into
user (username, salt, password_hash, admin)
values
-- daniel:password
(
    'daniel',
    'b795b80eb074b5107cac336d92a77b0dfd8d9960fc84d95c5f75850b9552540962b2662ac0a26c85f85546eb00c17f6b76f5205aec75147ea39ba741edcfdc2f', -- noqa: LT05, RF05
    "$argon2id$v=13$m=12228,t=3,p=1$Yjc5NWI4MGViMDc0YjUxMDdjYWMzMzZkOTJhNzdiMGRmZDhkOTk2MGZjODRkOTVjNWY3NTg1MGI5NTUyNTQwOTYyYjI2NjJhYzBhMjZjODVmODU1NDZlYjAwYzE3ZjZiNzZmNTIwNWFlYzc1MTQ3ZWEzOWJhNzQxZWRjZmRjMmY$Pcr7o0VsztpmKzyh+saztoBangn+MJCGjwvP0id7NC0", -- noqa: LT05, RF05
    1
)
returning id;
