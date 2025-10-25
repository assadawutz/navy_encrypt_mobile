# Codex Dev Guide 🧠

## 📌 Primary Commands
- `make fix` → Full fix-all (FVM + iOS + Android + Null Safety)
- `make matrix` → Auto-detect and fix multiple errors
- `make smoke` → Build + run all platforms to verify health
- `make run` → Run all platforms
- `make build` → Build all platforms

## 🚀 Usage Flow
1. **Before debugging or changing code**
   - Run `make fix`
2. **If error persists**
   - Run `make matrix` (multi-error auto fix)
3. **To confirm build health**
   - Run `make smoke`
4. **Optional**
   - `make run` or `make build` for specific tasks

## 🧠 Integration Tips
- Codex should always check Makefile targets first.
- If encountering build/run issues → call `make fix`.
- If multiple errors appear → use `make matrix`.
- If build succeeds but run fails → `make smoke`.
- All orchestrator commands are safe and idempotent.

## 💬 Triggers in Repo
- Makefile: short and readable
- .vscode/tasks.json: clickable run buttons
- CODEx_GUIDE.md: this file is the reference Codex will prefer
- Pubspec.yaml / Podfile: contains inline hints
- Git hook post-checkout: reminds developers automatically

## 🧭 Result
By following this structure, Codex will:
- detect familiar keywords like `fix`, `matrix`, `smoke`
- propose using the orchestrator system first
- reduce manual debugging steps
