"""
Tests for the Flask Todo API.

Structure:
    Each HTTP resource gets its own test class.
    Fixtures handle setup and teardown — tests themselves stay clean.

Why this matters for CI/CD:
    Jenkins runs these tests on every push. If any test fails, the pipeline
    stops and no broken code reaches the Docker image or any environment.
    These tests are the automated quality gate that replaces "works on my machine."
"""

import pytest

from app import create_app
from app.api import _todos


# ── Fixtures ──────────────────────────────────────────────────────────────────


@pytest.fixture()
def app():
    """Create a test Flask application with testing mode enabled."""
    application = create_app()
    application.config["TESTING"] = True
    return application


@pytest.fixture()
def client(app):
    """Return a test client for making HTTP requests without a running server."""
    return app.test_client()


@pytest.fixture(autouse=True)
def clear_store():
    """
    Reset the in-memory todo store before and after every test.

    Without this, a todo created in one test would still exist in the next.
    Tests must be independent — the order they run should never matter.
    This is a core testing principle that also applies in CI environments.
    """
    _todos.clear()
    yield
    _todos.clear()


# ── Health Endpoint ────────────────────────────────────────────────────────────


class TestHealth:
    def test_returns_200(self, client):
        response = client.get("/health")
        assert response.status_code == 200

    def test_returns_healthy_status(self, client):
        data = client.get("/health").get_json()
        assert data["status"] == "healthy"

    def test_includes_timestamp(self, client):
        data = client.get("/health").get_json()
        assert "timestamp" in data
        # Timestamp should be an ISO-8601 string
        assert "T" in data["timestamp"]


# ── Create Todo ────────────────────────────────────────────────────────────────


class TestCreateTodo:
    def test_returns_201(self, client):
        response = client.post("/todos", json={"title": "Learn Jenkins"})
        assert response.status_code == 201

    def test_returns_todo_with_generated_id(self, client):
        data = client.post("/todos", json={"title": "Learn Jenkins"}).get_json()
        assert "id" in data
        assert len(data["id"]) > 0

    def test_returns_todo_with_correct_title(self, client):
        data = client.post("/todos", json={"title": "Write a Jenkinsfile"}).get_json()
        assert data["title"] == "Write a Jenkinsfile"

    def test_todo_is_not_done_by_default(self, client):
        data = client.post("/todos", json={"title": "Not done yet"}).get_json()
        assert data["done"] is False

    def test_accepts_optional_description(self, client):
        data = client.post(
            "/todos",
            json={"title": "Study CI/CD", "description": "Focus on pipeline stages"},
        ).get_json()
        assert data["description"] == "Focus on pipeline stages"

    def test_description_defaults_to_empty_string(self, client):
        data = client.post("/todos", json={"title": "No description"}).get_json()
        assert data["description"] == ""

    def test_missing_title_returns_400(self, client):
        response = client.post("/todos", json={"description": "has no title"})
        assert response.status_code == 400

    def test_empty_title_returns_400(self, client):
        response = client.post("/todos", json={"title": ""})
        assert response.status_code == 400

    def test_empty_body_returns_400(self, client):
        response = client.post("/todos", json={})
        assert response.status_code == 400

    def test_includes_created_at_timestamp(self, client):
        data = client.post("/todos", json={"title": "Timestamped"}).get_json()
        assert "created_at" in data


# ── List Todos ─────────────────────────────────────────────────────────────────


class TestListTodos:
    def test_returns_empty_list_when_no_todos(self, client):
        data = client.get("/todos").get_json()
        assert data == []

    def test_returns_200(self, client):
        response = client.get("/todos")
        assert response.status_code == 200

    def test_returns_all_todos(self, client):
        client.post("/todos", json={"title": "First"})
        client.post("/todos", json={"title": "Second"})
        client.post("/todos", json={"title": "Third"})

        data = client.get("/todos").get_json()
        assert len(data) == 3

    def test_returns_correct_titles(self, client):
        client.post("/todos", json={"title": "Jenkins"})
        client.post("/todos", json={"title": "Docker"})

        titles = {todo["title"] for todo in client.get("/todos").get_json()}
        assert titles == {"Jenkins", "Docker"}


# ── Get Single Todo ────────────────────────────────────────────────────────────


class TestGetTodo:
    def test_returns_200_for_existing_todo(self, client):
        created = client.post("/todos", json={"title": "Existing"}).get_json()
        response = client.get(f"/todos/{created['id']}")
        assert response.status_code == 200

    def test_returns_correct_todo(self, client):
        created = client.post("/todos", json={"title": "Find me"}).get_json()
        fetched = client.get(f"/todos/{created['id']}").get_json()
        assert fetched["id"] == created["id"]
        assert fetched["title"] == "Find me"

    def test_returns_404_for_nonexistent_id(self, client):
        response = client.get("/todos/does-not-exist")
        assert response.status_code == 404


# ── Update Todo ────────────────────────────────────────────────────────────────


class TestUpdateTodo:
    def test_returns_200_on_success(self, client):
        created = client.post("/todos", json={"title": "Original"}).get_json()
        response = client.put(f"/todos/{created['id']}", json={"title": "Updated"})
        assert response.status_code == 200

    def test_updates_title(self, client):
        created = client.post("/todos", json={"title": "Old title"}).get_json()
        updated = client.put(
            f"/todos/{created['id']}", json={"title": "New title"}
        ).get_json()
        assert updated["title"] == "New title"

    def test_updates_description(self, client):
        created = client.post("/todos", json={"title": "Some task"}).get_json()
        updated = client.put(
            f"/todos/{created['id']}", json={"description": "Now has a description"}
        ).get_json()
        assert updated["description"] == "Now has a description"

    def test_marks_todo_as_done(self, client):
        created = client.post("/todos", json={"title": "Incomplete"}).get_json()
        updated = client.put(
            f"/todos/{created['id']}", json={"done": True}
        ).get_json()
        assert updated["done"] is True

    def test_unmarks_todo_as_done(self, client):
        created = client.post("/todos", json={"title": "Was done"}).get_json()
        client.put(f"/todos/{created['id']}", json={"done": True})
        updated = client.put(
            f"/todos/{created['id']}", json={"done": False}
        ).get_json()
        assert updated["done"] is False

    def test_partial_update_does_not_overwrite_other_fields(self, client):
        created = client.post(
            "/todos",
            json={"title": "Keep me", "description": "Keep this too"},
        ).get_json()
        # Only update `done` — title and description must be unchanged
        updated = client.put(
            f"/todos/{created['id']}", json={"done": True}
        ).get_json()
        assert updated["title"] == "Keep me"
        assert updated["description"] == "Keep this too"

    def test_returns_404_for_nonexistent_id(self, client):
        response = client.put("/todos/not-real", json={"title": "x"})
        assert response.status_code == 404


# ── Delete Todo ────────────────────────────────────────────────────────────────


class TestDeleteTodo:
    def test_returns_204_on_success(self, client):
        created = client.post("/todos", json={"title": "Delete me"}).get_json()
        response = client.delete(f"/todos/{created['id']}")
        assert response.status_code == 204

    def test_deleted_todo_is_no_longer_retrievable(self, client):
        created = client.post("/todos", json={"title": "Gone soon"}).get_json()
        client.delete(f"/todos/{created['id']}")
        response = client.get(f"/todos/{created['id']}")
        assert response.status_code == 404

    def test_deleted_todo_not_in_list(self, client):
        created = client.post("/todos", json={"title": "To be removed"}).get_json()
        client.delete(f"/todos/{created['id']}")
        remaining = client.get("/todos").get_json()
        ids = [t["id"] for t in remaining]
        assert created["id"] not in ids

    def test_returns_404_for_nonexistent_id(self, client):
        response = client.delete("/todos/not-real")
        assert response.status_code == 404
