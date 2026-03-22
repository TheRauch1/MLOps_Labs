import pytest


def answer_to_life_universe_everything():
    return 42


def test_answer():
    assert 42 == answer_to_life_universe_everything()


def test_answer_fail():
    assert 47 == answer_to_life_universe_everything()


def f():
    raise SystemExit(1)


def test_mytest():
    with pytest.raises(SystemExit):
        f()


def test_validation_error():
    with pytest.raises(ValueError):
        validate_answer(47)


def validate_answer(answer):
    if 42 != answer:
        raise ValueError(f"Answer {answer} is wrong.")


class TestClass:
    def test_one(self):
        x = "this"
        assert "h" in x

    def test_two(self):
        x = "hello"
        assert hasattr(x, "check")
