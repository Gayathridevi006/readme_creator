# relay. — Django Real-time Chat

Real-time group chat built with **Django + Django Channels + Daphne**.
Single-page UI, no JavaScript framework, no database required.

---

## Project structure

```
relay-django/
├── manage.py
├── relay/                  ← Django project package
│   ├── settings.py
│   ├── urls.py
│   └── asgi.py             ← ASGI entrypoint (HTTP + WebSocket routing)
└── chat/                   ← Chat Django app
    ├── consumers.py        ← WebSocket handler (AsyncWebsocketConsumer)
    ├── routing.py          ← WebSocket URL patterns
    ├── urls.py             ← HTTP URL patterns
    ├── views.py            ← Serves the single-page UI
    └── templates/chat/
        └── index.html      ← Full chat UI (HTML + CSS + JS)
```

---
## application create - 
django-admin startproject relay
cd relay
python manage.py startapp chat

## Quickstart

```bash
pip install -r requirements.txt
cd relay-django
python manage.py runserver
```

Open **http://localhost:8000**, enter a name, and start chatting.
Open a second tab to simulate a second user.

> **Why `runserver` works:** Daphne is listed first in `INSTALLED_APPS`,
> which makes `manage.py runserver` use Daphne (ASGI) instead of the
> default WSGI dev server — so WebSockets work out of the box.

### Production

```bash
daphne -b 0.0.0.0 -p 8000 relay.asgi:application
```

---

## How it works

### Django Channels layer

```
Browser  ←──WebSocket──→  ChatConsumer (AsyncWebsocketConsumer)
                                │
                         channel_layer.group_send("chat_general", …)
                                │
                         All connected ChatConsumers receive the event
                         and forward it to their WebSocket client
```

Each browser tab is a separate `ChatConsumer` instance.
`group_send` is how consumers talk to each other — it goes through the
**Channel Layer** (`InMemoryChannelLayer` here, swappable for Redis).

### WebSocket protocol

| Direction | Event | Payload |
|-----------|-------|---------|
| client → server | `message` | `{ type, text }` |
| client → server | `typing`   | `{ type }` |
| server → client | `history`  | `{ type, messages: [...] }` |
| server → client | `message`  | `{ type, username, text, ts }` |
| server → client | `system`   | `{ type, text, ts }` |
| server → client | `users`    | `{ type, users: [...] }` |
| server → client | `typing_start` | `{ type, username }` |
| server → client | `typing_stop`  | `{ type, username }` |

---

## Design decisions

### Messages persist in memory (last 100 replayed on join)

Refreshing to an empty room feels broken. In-memory history means new
joiners get context without needing a database. The trade-off is that
history is lost on server restart — easy to extend with Django ORM:

```python
# models.py
class Message(models.Model):
    username = models.CharField(max_length=24)
    text     = models.TextField()
    ts       = models.DateTimeField(auto_now_add=True)
```

### Self-declared username, no auth

Auth adds friction and infrastructure. A username prompt gives users
identity (you can see who's online, messages feel personal) without
passwords or sessions. Unique-name enforcement would need a server-side
registry with race conditions — overkill for this scope.

### One global room

Always someone to chat with. The `ConnectionManager` pattern and
`group_send` are room-agnostic; adding multi-room means keying the
group name by room slug (e.g. `chat_{room_name}`).

### InMemoryChannelLayer (no Redis)

Zero external dependencies. For a single-server deployment this is
correct. To scale horizontally, swap one line in `settings.py`:

```python
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {"hosts": [("127.0.0.1", 6379)]},
    }
}
```

### Bonus feature: Typing indicators

The single feature that most makes a chat feel alive. When you see
"alex is typing…" you know the connection is real.

**Implementation:** Client fires `{type: "typing"}` on each keystroke.
Server holds a per-username `asyncio.Task` that fires `typing_stop`
after 2 seconds of silence. Sending a message cancels the timer
immediately. Typing events are never persisted.

---

## Extending

| Feature | How |
|---------|-----|
| Persistent messages | Add `Message` Django model; query on connect |
| Multiple rooms | Key channel group by room slug in URL |
| Redis channel layer | `pip install channels-redis`; update `CHANNEL_LAYERS` |
| Auth | Add Django session middleware; read `request.user` in consumer scope |
| Reactions | Store `{msg_id → {emoji → [usernames]}}`, broadcast deltas |
