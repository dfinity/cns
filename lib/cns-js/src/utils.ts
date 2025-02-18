export function toCandidOpt<T>(value?: T | null): [] | [T] {
  if (value === undefined || value === null) {
    return [];
  }

  return [value];
}

export function fromCandidOpt<T>(value: [] | [T]): T | null {
  if (value.length === 0) {
    return null;
  }

  return value[0];
}

export function isNil<T>(
  value: T | null | undefined,
): value is null | undefined {
  return value === null || value === undefined;
}

export function isNotNil<T>(value: T | null | undefined): value is T {
  return !isNil(value);
}
