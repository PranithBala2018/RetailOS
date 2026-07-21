from app.common.response import error_envelope, success_envelope


def test_success_envelope_shape() -> None:
    envelope = success_envelope(data={"id": 1}, message="ok")
    assert envelope == {"success": True, "message": "ok", "data": {"id": 1}}


def test_success_envelope_defaults() -> None:
    envelope = success_envelope()
    assert envelope["success"] is True
    assert envelope["data"] is None


def test_error_envelope_shape() -> None:
    envelope = error_envelope(message="bad", errors=[{"code": "x"}])
    assert envelope == {"success": False, "message": "bad", "errors": [{"code": "x"}]}


def test_error_envelope_defaults_to_empty_errors_list() -> None:
    envelope = error_envelope()
    assert envelope["errors"] == []
