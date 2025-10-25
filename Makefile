fix-all:
	./dev-orchestrator.sh --deep && ./dev-orchestrator.sh --build-all --parallel && ./dev-orchestrator.sh --run-all && ./dev-orchestrator.sh --report
smoke:
	./dev-orchestrator.sh --smoke --parallel
matrix:
	./dev-orchestrator.sh --matrix
ios:
	./dev-orchestrator.sh --ios
android:
	./dev-orchestrator.sh --android
report:
	./dev-orchestrator.sh --report
help:
	@grep -E '^[a-zA-Z_-]+:.*' Makefile | sed 's/:.*/: /'
