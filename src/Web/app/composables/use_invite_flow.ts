// app/composables/useInviteFlow.ts
import { toast } from "vue-sonner";
import { inviteTokenSchema } from "~~/shared/invitations/schemas";

const STORAGE_KEY = "minicrm:invite-token";

// Where a person lands after joining. Change this if your business dashboard lives elsewhere.
const afterJoin = (businessId: number) => `/business/${businessId}/team`;

export type InviteView =
  | "loading"
  | "invalid"
  | "error"
  | "dead"
  | "not-eligible"
  | "register"
  | "signin"
  | "accept"
  | "wrong-account"
  | "registered";

export function useInviteFlow() {
  const { user, fetch: fetchSession } = useUserSession();

  const token = ref<string | null>(null);
  const preview = ref<InvitationPreview | null>(null);
  const loading = ref(true);
  const failure = ref<{ status: number; message: string } | null>(null);
  const accepting = ref(false);
  const acceptError = ref<string | null>(null);
  const registeredAs = ref<string | null>(null); // business name, when the account exists but automatic sign-in failed

  /**
   * The emailed link is /invite#<token>. A fragment never reaches a server or an access log.
   * Read it once, strip it from the address bar and history, and keep it in sessionStorage so it
   * survives sign-in, registration and page reloads.
   */
  function readToken(): string | null {
    const fromHash = location.hash.replace(/^#/, "");
    if (fromHash) {
      history.replaceState(
        history.state,
        "",
        location.pathname + location.search,
      );
      if (inviteTokenSchema.safeParse(fromHash).success) {
        sessionStorage.setItem(STORAGE_KEY, fromHash);
        return fromHash;
      }
      return null;
    }
    const stored = sessionStorage.getItem(STORAGE_KEY);
    return stored && inviteTokenSchema.safeParse(stored).success
      ? stored
      : null;
  }

  async function load() {
    loading.value = true;
    failure.value = null;
    try {
      preview.value = await $fetch<InvitationPreview>(
        "/api/invitations/preview",
        {
          method: "POST",
          body: { token: token.value },
        },
      );
    } catch (e) {
      failure.value = { status: errorStatus(e), message: errorMessage(e) };
    } finally {
      loading.value = false;
    }
  }

  async function init() {
    token.value = readToken();
    if (!token.value) {
      loading.value = false;
      return;
    }
    await load();
  }

  const view = computed<InviteView>(() => {
    if (registeredAs.value) return "registered";
    if (loading.value) return "loading";
    if (failure.value)
      return [400, 404].includes(failure.value.status) ? "invalid" : "error";

    const p = preview.value;
    if (!token.value || !p) return "invalid";
    if (p.status !== "Pending") return "dead";

    if (user.value) {
      if (user.value.role !== "Business") return "not-eligible";
      // A hint only. The API compares the real addresses and answers 403 with an explanation on a mismatch.
      return maskEmail((user.value.email ?? "").toLowerCase()) === p.emailHint
        ? "accept"
        : "wrong-account";
    }

    if (p.accountState === "ClientAccount" || p.accountState === "OtherAccount")
      return "not-eligible";
    return p.accountState === "NoAccount" ? "register" : "signin";
  });

  async function finish(
    businessId: number,
    businessName: string,
    alreadyMember: boolean,
  ) {
    sessionStorage.removeItem(STORAGE_KEY);
    toast.success(
      alreadyMember
        ? `You're already on the ${businessName} team.`
        : `You joined ${businessName}.`,
    );
    await navigateTo(afterJoin(businessId));
  }

  /** Joining is always an explicit click. Opening the link never grants access. */
  async function accept() {
    if (!token.value) return;
    accepting.value = true;
    acceptError.value = null;
    try {
      const r = await $fetch<AcceptInvitationResult>(
        "/api/backend/invitations/accept",
        {
          method: "POST",
          body: { token: token.value },
        },
      );
      await finish(r.businessId, r.businessName, r.alreadyMember);
    } catch (e) {
      acceptError.value = errorMessage(
        e,
        "We couldn't add you to this team. Try again.",
      );
      // The invitation changed while the page was open (used, cancelled): show what it is now.
      if ([409, 410].includes(errorStatus(e))) await load();
    } finally {
      accepting.value = false;
    }
  }

  async function onRegistered(result: JoinResult) {
    if (result.signedIn) {
      await fetchSession();
      await finish(result.businessId, result.businessName, false);
    } else {
      sessionStorage.removeItem(STORAGE_KEY);
      registeredAs.value = result.businessName;
    }
  }

  async function onSignedIn() {
    await fetchSession(); // the view recomputes: accept button, or wrong-account
  }

  async function logout() {
    try {
      await $fetch("/api/auth/logout", { method: "POST" });
    } catch {
        toast.error("failed to logout");
    } finally {
      await fetchSession();
    }
  }

  return {
    user,
    token,
    preview,
    view,
    failure,
    accepting,
    acceptError,
    registeredAs,
    init,
    load,
    accept,
    logout,
    onRegistered,
    onSignedIn,
  };
}
