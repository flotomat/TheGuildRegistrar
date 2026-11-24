#!/usr/bin/env python3
"""Automatic versioning and release notes from commit messages.

Commit message prefixes (Conventional Commits) decide the next version A.B.C:

  A (major)  feat!: / fix!: ... (a "!" before the colon), "BREAKING CHANGE:" in the
             message body, or major: ...                      -> A+1.0.0
  B (minor)  feat: ...                                        -> A.B+1.0
  C (patch)  fix:, docs:, ui:, style:, perf:, refactor:, l10n:, i18n:, revert:
             and commits without a prefix                     -> A.B.C+1
  none       ci:, build:, chore:, test:  (no release on their own)

The highest level among all commits since the last tag wins; lower places restart at 0.

Usage:
  release.py next                 print/emit the next tag (empty if no release is due)
  release.py notes <tag> <file>   write the release notes for <tag> to <file>
"""

import datetime
import os
import re
import subprocess
import sys

HEADER = re.compile(r"^(?P<type>[A-Za-z0-9]+)(?:\((?P<scope>[^)]*)\))?(?P<bang>!)?:\s*(?P<text>.+)$")

PATCH_TYPES = {"fix", "docs", "ui", "style", "perf", "refactor", "l10n", "i18n", "revert"}
SILENT_TYPES = {"ci", "build", "chore", "test", "tests"}

LEVELS = {"none": 0, "patch": 1, "minor": 2, "major": 3}

SECTIONS = [
    ("major", "Breaking changes"),
    ("feat", "New features"),
    ("fix", "Fixes"),
    ("ui", "Interface"),
    ("docs", "Documentation"),
    ("other", "Other changes"),
]

SECTION_OF_TYPE = {
    "feat": "feat",
    "fix": "fix",
    "revert": "fix",
    "ui": "ui",
    "style": "ui",
    "docs": "docs",
    "l10n": "other",
    "i18n": "other",
    "perf": "other",
    "refactor": "other",
}

VERSION_TAG = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True,
                          encoding="utf-8").stdout


def last_tag(rev="HEAD"):
    """Most recent vA.B.C tag reachable from rev, or None."""
    try:
        out = git("describe", "--tags", "--abbrev=0", "--match", "v[0-9]*.[0-9]*.[0-9]*", rev)
    except subprocess.CalledProcessError:
        return None
    tag = out.strip()
    return tag if VERSION_TAG.match(tag) else None


def commits(rev_range):
    """List of (short hash, subject, body) for non-merge commits, oldest first."""
    out = git("log", "--no-merges", "--reverse", "--format=%h%x1f%s%x1f%b%x1e", rev_range)
    result = []
    for record in out.split("\x1e"):
        record = record.strip("\n")
        if not record:
            continue
        short, subject, body = (record.split("\x1f") + ["", ""])[:3]
        result.append((short, subject.strip(), body))
    return result


def classify(subject, body):
    """Return (level, section, scope, text) for one commit."""
    m = HEADER.match(subject)
    breaking = "BREAKING CHANGE:" in body or "BREAKING-CHANGE:" in body
    if not m:
        return ("major" if breaking else "patch", "major" if breaking else "other", None, subject)
    ctype = m.group("type").lower()
    scope = m.group("scope")
    text = m.group("text").strip()
    if breaking or m.group("bang") or ctype == "major":
        return "major", "major", scope, text
    if ctype == "feat":
        return "minor", "feat", scope, text
    if ctype in SILENT_TYPES:
        return "none", None, scope, text
    if ctype in PATCH_TYPES:
        return "patch", SECTION_OF_TYPE.get(ctype, "other"), scope, text
    # unknown prefix: treat as a small change
    return "patch", "other", scope, subject


def bump(version, level):
    a, b, c = version
    if level == "major":
        return a + 1, 0, 0
    if level == "minor":
        return a, b + 1, 0
    if level == "patch":
        return a, b, c + 1
    return version


def emit(**values):
    out_file = os.environ.get("GITHUB_OUTPUT")
    for key, value in values.items():
        print(f"{key}={value}")
    if out_file:
        with open(out_file, "a", encoding="utf-8") as fh:
            for key, value in values.items():
                fh.write(f"{key}={value}\n")


def cmd_next():
    tag = last_tag()
    if tag:
        current = tuple(int(x) for x in VERSION_TAG.match(tag).groups())
        rev_range = f"{tag}..HEAD"
    else:
        current = (0, 0, 0)
        rev_range = "HEAD"
    level = "none"
    for short, subject, body in commits(rev_range):
        commit_level = classify(subject, body)[0]
        print(f"  {short} [{commit_level}] {subject}", file=sys.stderr)
        if LEVELS[commit_level] > LEVELS[level]:
            level = commit_level
    if level == "none":
        print(f"No release-relevant changes since {tag or 'the start'}.", file=sys.stderr)
        emit(bump="none", tag="")
        return
    new_tag = "v%d.%d.%d" % bump(current, level)
    print(f"{tag or 'v0.0.0'} -> {new_tag} ({level})", file=sys.stderr)
    emit(bump=level, tag=new_tag)


def cmd_notes(tag, path):
    previous = last_tag(f"{tag}^")
    rev_range = f"{previous}..{tag}" if previous else tag
    grouped = {key: [] for key, _ in SECTIONS}
    for short, subject, body in commits(rev_range):
        _, section, scope, text = classify(subject, body)
        if section is None:
            continue
        text = text[:1].upper() + text[1:]
        line = f"- **{scope}:** {text} ({short})" if scope else f"- {text} ({short})"
        grouped[section].append(line)

    date = git("log", "-1", "--format=%cs", tag).strip() or datetime.date.today().isoformat()
    lines = [f"## {tag} ({date})", ""]
    if not any(grouped.values()):
        lines += ["- Maintenance release.", ""]
    for key, title in SECTIONS:
        if grouped[key]:
            lines += [f"### {title}", "", *grouped[key], ""]
    if previous:
        repo = os.environ.get("GITHUB_REPOSITORY")
        server = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
        compare = f"{previous}...{tag}"
        lines += [f"All changes: [{compare}]({server}/{repo}/compare/{compare})" if repo
                  else f"All changes: {compare}", ""]
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))
    print("\n".join(lines))


def main(argv):
    if len(argv) == 2 and argv[1] == "next":
        cmd_next()
    elif len(argv) == 4 and argv[1] == "notes":
        cmd_notes(argv[2], argv[3])
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
