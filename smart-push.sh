#!/usr/bin/env bash
# ============================================================
# smart-push.sh — one command to sync, commit, and push
#
# USAGE:
#   bash smart-push.sh "feat: added login validation"
#
# Optional: give a branch name as 2nd argument if you want to
# create/switch to a specific branch first:
#   bash smart-push.sh "feat: added login validation" feature/login-fix
# ============================================================
set -e

MSG="$1"
BRANCH_ARG="$2"

if [ -z "$MSG" ]; then
  echo "Usage: bash smart-push.sh \"feat: your commit message\" [branch-name]"
  exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Detect whether this repo's integration branch is "main" or "master"
if git show-ref --quiet refs/remotes/origin/main; then
  BASE_BRANCH="main"
else
  BASE_BRANCH="master"
fi

# 1. Make sure we're on a proper branch, not the integration branch -------
if [ -n "$BRANCH_ARG" ]; then
  if git show-ref --quiet refs/heads/"$BRANCH_ARG"; then
    echo "==> Switching to existing branch $BRANCH_ARG"
    git checkout "$BRANCH_ARG"
  else
    echo "==> Creating new branch $BRANCH_ARG"
    git checkout -b "$BRANCH_ARG"
  fi
  CURRENT_BRANCH="$BRANCH_ARG"
elif [ "$CURRENT_BRANCH" == "master" ] || [ "$CURRENT_BRANCH" == "main" ]; then
  # auto-generate a branch name from the commit message
  SLUG=$(echo "$MSG" | sed -E 's/^[a-z]+:? ?//i' | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed -E 's/-+/-/g; s/^-|-$//g' | cut -c1-40)
  NEW_BRANCH="feature/${SLUG}"
  echo "==> You're on $CURRENT_BRANCH. Creating $NEW_BRANCH instead."
  git checkout -b "$NEW_BRANCH"
  CURRENT_BRANCH="$NEW_BRANCH"
else
  echo "==> Staying on current branch: $CURRENT_BRANCH"
fi

# 2. Sync with latest integration branch -----------------------------------
echo "==> Fetching latest from origin..."
git fetch origin

echo "==> Merging origin/$BASE_BRANCH into $CURRENT_BRANCH..."
if ! git merge origin/"$BASE_BRANCH" --no-edit; then
  echo ""
  echo "!! MERGE CONFLICT detected."
  echo "Resolve the conflicts shown above, then run:"
  echo "   git add ."
  echo "   git commit"
  echo "   bash smart-push.sh \"$MSG\""
  exit 1
fi

# 3. Stage everything -------------------------------------------------------
echo "==> Staging changes..."
git add .

# 4. Commit (build gate runs here via pre-commit hook) -----------------------
echo "==> Committing (this will trigger the build check)..."
if ! git commit -m "$MSG"; then
  echo ""
  echo "!! Commit blocked — fix the build error or commit message format above, then re-run:"
  echo "   bash smart-push.sh \"$MSG\""
  exit 1
fi

# 5. Push ---------------------------------------------------------------------
echo "==> Pushing $CURRENT_BRANCH to origin..."
git push -u origin "$CURRENT_BRANCH"

echo ""
echo "DONE. Branch '$CURRENT_BRANCH' is pushed."
echo "Go to Bitbucket now and click 'Create pull request' for this branch."
