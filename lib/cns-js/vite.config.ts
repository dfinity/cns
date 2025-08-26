import { resolve } from 'path';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  build: {
    lib: {
      entry: resolve(__dirname, 'src', 'index.ts'),
      name: '@dfinity/cns',
      fileName: 'cns',
    },
    sourcemap: true,
    rollupOptions: {
      external: ['@icp-sdk/core/agent', '@icp-sdk/core/principal'],
      output: {
        globals: {
          '@icp-sdk/core/agent': 'icp-sdk-core-agent',
          '@icp-sdk/core/principal': 'icp-sdk-core-principal',
        },
      },
    },
  },
  test: {
    root: 'tests',
    globalSetup: './tests/global-setup.ts',
    testTimeout: 30_000,
    typecheck: {
      tsconfig: './tsconfig.test.json',
    },
  },
});
