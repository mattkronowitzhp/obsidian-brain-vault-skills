---
name: brain-file
description: File a research answer, analysis, or synthesis as a permanent wiki page in the user's Brain vault. Use when Claude did real work that shouldn't disappear into chat history. Trigger with /brain-file or suggest when an answer is meaty enough to deserve filing.
---

# brain-file

File a research answer, analysis, or synthesis as a permanent wiki page in the Brain vault. Use when Claude did real work that shouldn't disappear into chat history.

## When to use

- **After research:** provider comparisons, architecture breakdowns, interview prep, competitive analysis
- **After synthesis:** connecting dots across multiple sources or conversations
- **After analysis:** debugging deep-dives, cost breakdowns, decision matrices
- **Rule of thumb:** if the answer took more than a quick reply, it should be filed

Claude should suggest filing when appropriate: "This was a meaty answer — want me to file it to the vault?"

User can also trigger manually: `/brain-file`

## How to file

1. **Determine the workspace folder.** Read `~/Brain/_System/workspaces.yaml` and match the content to the right workspace by keywords/people. If no workspace matches well, ask the user.

2. **Check for existing pages.** One canonical source per topic. If a relevant page already exists, update it — don't create a duplicate.

3. **Write the page.** Format:
   ```markdown
   # Title

   Content here — terse, third person on structured pages.
   Match the voice of existing workspace pages.

   ## Related
   - [[relevant-page]]
   ```

4. **Update related pages.** If the new page is relevant to an existing page, add a wikilink there too. Rewrite-not-append — integrate, don't dump.

5. **Update the index.** Add a one-liner to `_System/index.md` under the right section.

6. **Confirm to user.** Print what was filed and where:
   ```
   Filed → <workspace>/<page>.md
   Updated → <workspace>/<related-page>.md (added link)
   Index → updated
   ```

## Rules

- **Third person, terse** on structured wiki pages. Match the voice of the workspace.
- **Don't over-write.** File the substance, not the chat context. If the research was 500 words of analysis, the page might be 200 words of distilled knowledge.
- **One canonical page per topic.** Check before creating. Update existing pages when possible.
- **Wikilinks.** Link to related pages. Link from related pages back.
- **No frontmatter** unless the workspace already uses it.
- **Don't file trivial answers.** Quick lookups, one-liners, and simple factual responses don't need pages.

## What NOT to file

- Chat-specific context ("you asked me to...")
- Temporary debugging output
- Things already captured by `/brain-triage` or `/claude-log`
- Opinions or recommendations unless the user asked for a decision page
