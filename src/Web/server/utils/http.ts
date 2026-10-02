export function fail(statusCode: number, message: string, errors?: unknown) {
  return createError({ statusCode, message, data: { message, errors } });
}
export function toH3Error(err: any) {
  if (isError(err)) {
    return err;
  }

  const status = err?.response?.status;

  if (!status) {
    return fail(503, "Impossible de joindre le serveur.");
  }

  const problem = err?.data ?? err?.response?._data;

  if (status >= 500) {
    return fail(status, "Une erreur interne est survenue.");
  }

  const message =
    problem?.detail ??
    problem?.message ??
    problem?.title ??
    "La requête a échoué.";

  return fail(status, message, problem?.errors);
}