"""What the app sends and gets back about a reader. Inputs are strict: known values
only, capped sizes, unknown fields refused."""

from typing import Annotated, Literal

from pydantic import AfterValidator, BaseModel, ConfigDict, Field, StringConstraints

# Interface languages OSMS writes in: code → (native name, English name).
LANGUAGES = {"en": ("English", "English"), "da": ("Dansk", "Danish"), "ta": ("தமிழ்", "Tamil")}

# One account can't swamp the fetcher or the database.
MAX_SUBSCRIPTIONS = 500
MAX_INTERESTS = 20
MAX_TERMS = 20

Language = Literal["en", "da", "ta"]
Kind = Literal["article", "paper", "episode", "post", "video", "photo", "comic"]
Layout = Literal["card", "row"]
Term = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
Category = Annotated[str, StringConstraints(pattern=r"^[a-z-]+(\.[A-Za-z-]+)?$", max_length=32)]


def _unique[T](values: list[T]) -> list[T]:
    return list(dict.fromkeys(values))


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class LanguageOut(BaseModel):
    code: str
    native_name: str
    english_name: str


class TopicOut(BaseModel):
    id: str
    name: str
    description: str


class SourceOut(BaseModel):
    id: str
    name: str
    type: str
    language: str
    url: str | None


class SuggestionOut(BaseModel):
    topic_id: str
    kind: Kind
    note: str | None
    source: SourceOut


class OnboardingOptions(BaseModel):
    languages: list[LanguageOut]
    topics: list[TopicOut]
    suggestions: list[SuggestionOut]


class InterestIn(Strict):
    keywords: Annotated[list[Term], Field(min_length=1, max_length=MAX_TERMS), AfterValidator(_unique)]
    related_terms: Annotated[list[Term], Field(max_length=MAX_TERMS), AfterValidator(_unique)] = []
    categories: Annotated[list[Category], Field(max_length=MAX_TERMS), AfterValidator(_unique)] = []


class InterestOut(InterestIn):
    model_config = ConfigDict(extra="ignore")
    id: str


class Appearance(Strict):
    mode: Literal["system", "light", "dark"] = "system"
    palette_id: Annotated[str, StringConstraints(pattern=r"^[a-z0-9-]{1,32}$")] = "folio"
    pure_black: bool = False
    reading_font: Literal["serif", "sans"] = "serif"
    reading_scale: Annotated[float, Field(ge=0.85, le=1.4)] = 1.0
    glass: Literal["frosted", "tinted", "solid"] = "frosted"


class OnboardingIn(Strict):
    language: Language
    topics: Annotated[list[str], Field(max_length=50), AfterValidator(_unique)]
    kinds: Annotated[list[Kind], Field(max_length=7), AfterValidator(_unique)]
    source_ids: Annotated[list[str], Field(max_length=MAX_SUBSCRIPTIONS), AfterValidator(_unique)]
    interests: Annotated[list[InterestIn], Field(max_length=MAX_INTERESTS)] = []


class InterestsIn(Strict):
    interests: Annotated[list[InterestIn], Field(max_length=MAX_INTERESTS)]


class SettingsIn(Strict):
    language: Language | None = None
    appearance: Appearance | None = None
    default_layout: Layout | None = None


class MeOut(BaseModel):
    id: str
    email: str
    display_name: str
    language: str
    kinds: list[str]
    topics: list[TopicOut]
    subscriptions: list[SourceOut]
    interests: list[InterestOut]
    appearance: Appearance | None
    default_layout: str | None
    onboarded: bool
