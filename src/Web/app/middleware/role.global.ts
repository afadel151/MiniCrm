export default defineNuxtRouteMiddleware((to, from) => {
  const { user } = useUserSession();
  const requiredRoles = to.meta.roles as string[] | undefined;

  if (!requiredRoles?.length) {
    return;
  }

  const userRole = user.value?.role;

  if (!userRole || !requiredRoles.includes(userRole)) {
    return navigateTo({
      path: "/access_denied",
      query: {
        redirect: from.path,
      },
    });
  }
});
