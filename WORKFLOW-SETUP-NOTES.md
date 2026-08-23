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
