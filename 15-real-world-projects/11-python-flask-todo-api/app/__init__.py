from flask import Flask


def create_app():
    """
    Application factory — creates and returns the Flask app instance.

    Using a factory function (rather than a module-level `app = Flask(__name__)`)
    means we can create fresh app instances in tests without shared state.
    This is the recommended pattern for any non-trivial Flask application.
    """
    app = Flask(__name__)

    from .api import bp

    app.register_blueprint(bp)

    return app
