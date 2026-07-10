import { test, expect } from '@playwright/test';

test.describe('Dummy Quality Gate', () => {
  test('should pass - connection test', async () => {
    expect(true).toBeTruthy();
  });

  test('should fail - validation test', async () => {
    // Esse teste é feito para falhar intencionalmente para 
    // testarmos a capacidade do Hermes de ler o log de erros.
    expect(false).toBeTruthy();
  });
});
