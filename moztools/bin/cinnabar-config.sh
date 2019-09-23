git config fetch.prune true

git remote add try hg::https://hg.mozilla.org/try
git config remote.try.skipDefaultUpdate true
git remote set-url --push try hg::ssh://hg.mozilla.org/try
git config remote.try.push +HEAD:refs/heads/branches/default/tip
