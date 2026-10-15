// Keep older native hosts from silently returning an unchanged activation state.
export async function activateFreeAccess(request, publish) {
  try {
    let account, checkedStatus = false;
    try { account = await request('freeAccount', { operation:'activate' }); }
    catch (error) {
      // Older hosts reject an empty activation acknowledgement as invalid JSON.
      // A read-only status check can confirm success without repeating activation.
      if (error.message !== 'err.freeService') throw error;
      try { account = await request('freeAccount', { operation:'status' }); checkedStatus = true; } catch { throw error; }
      if (account?.activated !== true) throw error;
    }
    const update = value => {
      if (!value || typeof value !== 'object' || Array.isArray(value) || typeof value.activated !== 'boolean') throw Error('err.freeService');
      publish(value);
    };
    update(account);
    if (!checkedStatus && (account.activated !== true || account.quota?.remaining == null)) {
      account = await request('freeAccount', { operation:'status' });
      update(account);
    }
    if (account?.activated !== true) throw Error('err.freeNotActivated');
    return account;
  } catch (error) {
    // A host can persist the official entitlement before a quota request fails.
    // Restore that local state without retrying the rejected network request.
    try {
      const account = await request('freeAccount', { operation:'local' }, { timeout:5000 });
      if (account && typeof account.activated === 'boolean') publish(account);
    } catch { /* Keep the last known account. */ }
    throw error;
  }
}
