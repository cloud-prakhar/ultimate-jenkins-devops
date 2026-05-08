from datetime import datetime, timezone
import uuid

from flask import Blueprint, abort, jsonify, request

bp = Blueprint("api", __name__)

# In-memory store — every running instance has its own copy.
# Good enough for learning CI/CD; replace with a database in production.
_todos: dict = {}


def _store() -> dict:
    """Return the todos store.

    Wrapping access in a function makes it easy to swap in a test fixture
    without patching module-level globals directly.
    """
    return _todos


# ── Health ────────────────────────────────────────────────────────────────────


@bp.route("/health")
def health():
    """
    Health check endpoint — required by every production service.

    Kubernetes liveness and readiness probes, load balancers, and monitoring
    tools all call /health to decide whether a pod is alive and ready to
    receive traffic. A pipeline can also hit this endpoint after deployment
    to confirm the app started correctly (smoke test).
    """
    return jsonify(
        {
            "status": "healthy",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    )


# ── Todos ─────────────────────────────────────────────────────────────────────


@bp.route("/todos", methods=["GET"])
def list_todos():
    """Return all todos as a JSON array."""
    return jsonify(list(_store().values()))


@bp.route("/todos", methods=["POST"])
def create_todo():
    """
    Create a new todo.

    Expected request body:
        {"title": "string", "description": "optional string"}

    Returns the created todo with HTTP 201 Created.
    """
    body = request.get_json(silent=True) or {}

    if not body.get("title"):
        abort(400, description="'title' is required")

    todo_id = str(uuid.uuid4())
    todo = {
        "id": todo_id,
        "title": body["title"],
        "description": body.get("description", ""),
        "done": False,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    _store()[todo_id] = todo
    return jsonify(todo), 201


@bp.route("/todos/<todo_id>", methods=["GET"])
def get_todo(todo_id):
    """Return a single todo by ID, or 404 if it does not exist."""
    todo = _store().get(todo_id)
    if todo is None:
        abort(404, description=f"Todo '{todo_id}' not found")
    return jsonify(todo)


@bp.route("/todos/<todo_id>", methods=["PUT"])
def update_todo(todo_id):
    """
    Update an existing todo.

    Only fields present in the request body are updated (partial update).
    Returns the updated todo.
    """
    todo = _store().get(todo_id)
    if todo is None:
        abort(404, description=f"Todo '{todo_id}' not found")

    body = request.get_json(silent=True) or {}

    if "title" in body:
        todo["title"] = body["title"]
    if "description" in body:
        todo["description"] = body["description"]
    if "done" in body:
        todo["done"] = bool(body["done"])

    return jsonify(todo)


@bp.route("/todos/<todo_id>", methods=["DELETE"])
def delete_todo(todo_id):
    """Delete a todo. Returns 204 No Content on success, 404 if not found."""
    if todo_id not in _store():
        abort(404, description=f"Todo '{todo_id}' not found")
    del _store()[todo_id]
    return "", 204
