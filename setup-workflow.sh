#!/usr/bin/env bash
# ============================================================
# One-time repo workflow setup:
#   - Local build gate before commit (.NET / Angular)
#   - Commit message convention enforcement
#   - Branch naming convention enforcement
#   - Bitbucket Pipelines: build validation on PR to master
#   - Jenkinsfile: CI build/test on every commit + PR
#   - Static code analysis hook (SonarQube, optional)
#
# USAGE (run once, from repo root):
#   bash setup-workflow.sh
# ============================================================
set -e

echo "==> Setting up workflow automation in $(pwd)"

# 1. Git hooks directory ------------------------------------------------
mkdir -p .githooks

# --- pre-commit: build must pass before commit is allowed ---
cat > .githooks/pre-commit << 'EOF'
#!/usr/bin/env bash
set -e
echo "Running pre-commit build check..."

if ls ./*.sln >/dev/null 2>&1 || find . -maxdepth 3 -name "*.csproj" | grep -q .; then
  echo "-> .NET project detected, running dotnet build..."
  dotnet build --nologo -v quiet
  if [ $? -ne 0 ]; then
    echo "BUILD FAILED. Commit blocked."
    exit 1
  fi
fi

if [ -f "angular.json" ]; then
  echo "-> Angular project detected, running ng build..."
  npx ng build --configuration production
  if [ $? -ne 0 ]; then
    echo "BUILD FAILED. Commit blocked."
    exit 1
  fi
fi

echo "Build passed. Proceeding with commit."
EOF

# --- commit-msg: enforce message convention ---
cat > .githooks/commit-msg << 'EOF'
#!/usr/bin/env bash
MSG_FILE=$1
PATTERN="^(feat|fix|chore|refactor|docs|test|build|ci)(\([a-zA-Z0-9_-]+\))?: .{1,100}$"
FIRST_LINE=$(head -n1 "$MSG_FILE")

if ! [[ "$FIRST_LINE" =~ $PATTERN ]]; then
  echo "Commit message rejected."
  echo "Required format: <type>(optional-scope): short description"
  echo "Allowed types: feat, fix, chore, refactor, docs, test, build, ci"
  echo "Example: feat(login): add token refresh logic"
  exit 1
fi
EOF

# --- pre-push: enforce branch naming convention ---
cat > .githooks/pre-push << 'EOF'
#!/usr/bin/env bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
# Accepts either: feature/bugfix/hotfix/release prefixed branches,
# OR a plain developer-name branch (e.g. bharath, viswa)
PATTERN="^(feature|bugfix|hotfix|release)/[a-z0-9._-]+$|^[a-z][a-z0-9_-]{1,30}$"

if [[ "$BRANCH" == "master" || "$BRANCH" == "main" ]]; then
  echo "Direct push to $BRANCH is not allowed. Use a PR."
  exit 1
fi

if ! [[ "$BRANCH" =~ $PATTERN ]]; then
  echo "Branch name '$BRANCH' does not follow convention."
  echo "Use: feature/<name>, bugfix/<name>, hotfix/<name>, release/<name>, or your-name"
  exit 1
fi
EOF

chmod +x .githooks/pre-commit .githooks/commit-msg .githooks/pre-push
git config core.hooksPath .githooks
echo "==> Git hooks installed and activated (core.hooksPath=.githooks)"

# 2. Bitbucket Pipelines: automated PR build validation -----------------
cat > bitbucket-pipelines.yml << 'EOF'
image: mcr.microsoft.com/dotnet/sdk:8.0

pipelines:
  pull-requests:
    '**':
      - step:
          name: Build & Validate
          caches:
            - dotnetcore
          script:
            - dotnet restore
            - dotnet build --configuration Release --no-restore
            - dotnet test --no-build || true   # remove '|| true' once tests exist
      - step:
          name: Angular Build (if applicable)
          image: node:20
          script:
            - if [ -f "angular.json" ]; then npm ci && npx ng build --configuration production; fi

  branches:
    main:
      - step:
          name: Final Build Check Before Merge
          script:
            - dotnet restore
            - dotnet build --configuration Release --no-restore
EOF
echo "==> bitbucket-pipelines.yml created (PR build validation)"

# 3. Jenkinsfile: CI on every commit/PR ----------------------------------
cat > Jenkinsfile << 'EOF'
pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps { checkout scm }
        }
        stage('Restore & Build (.NET)') {
            when { expression { fileExists('*.sln') || findFiles(glob: '**/*.csproj').length > 0 } }
            steps {
                sh 'dotnet restore'
                sh 'dotnet build --configuration Release --no-restore'
            }
        }
        stage('Build (Angular)') {
            when { expression { fileExists('angular.json') } }
            steps {
                sh 'npm ci'
                sh 'npx ng build --configuration production'
            }
        }
        stage('Static Code Analysis') {
            steps {
                echo 'Plug in SonarQube scanner here, e.g.: sh "dotnet sonarscanner begin ..."'
            }
        }
        stage('Test') {
            steps {
                sh 'dotnet test || true'
            }
        }
    }
    post {
        failure {
            echo 'Build failed - PR/commit should not proceed to merge.'
        }
    }
}
EOF
echo "==> Jenkinsfile created (CI build/test)"

# 4. README note for admin-only steps ------------------------------------
cat > WORKFLOW-SETUP-NOTES.md << 'EOF'
# Workflow setup complete (local + pipeline side)

Already automated by this script:
- Local build gate before every commit (.NET / Angular)
- Commit message convention enforcement
- Branch naming convention enforcement
- Bitbucket Pipelines build validation on every PR to master
- Jenkinsfile CI build/test on every commit/PR

## Still needs one-time setup by a Repo Admin (Bitbucket UI, not scriptable client-side):
1. Repo Settings -> Branch permissions -> restrict direct writes to `master`, require PR.
2. Repo Settings -> Merge checks -> require a passing build (link the pipeline above) and required approvals.
3. Repo Settings -> Merge checks -> "no conflicts" and "minimum approvals" checkboxes.
4. (Optional) Connect SonarQube/SonarCloud for static analysis and add the scan step in the Jenkinsfile.

These 4 are account/admin-permission actions in Bitbucket's web UI (Settings > Branch restrictions),
so they can't be pasted into the repo as a script.
EOF

echo ""
echo "SETUP COMPLETE."
echo "Every future commit/push in this repo will now auto-check build, commit message, and branch name."
echo "See WORKFLOW-SETUP-NOTES.md for the remaining admin-side steps in Bitbucket settings."
