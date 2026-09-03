.PHONY: test test-dart test-javascript typecheck

test: test-dart test-javascript

test-dart:
	cd packages/dart && flutter pub get && flutter test

test-javascript:
	cd packages/javascript && pnpm install && pnpm run ci

typecheck:
	cd packages/javascript && pnpm install && pnpm build && pnpm typecheck
