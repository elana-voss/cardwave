// "Add to your persona?" (board MkPersona), once, over the new character's page: what the interview learned about the
// user, each line ticked, and which persona it goes to, the one in use or a new one. Add appends the ticked lines to
// its description; Not now, Escape and the × add nothing. No facts, no dialog.
import { createPersona, changePersona, listPersonas } from "../api/client";
import type { Persona } from "../api/generated/Persona";
import { account } from "../account";
import { dialog } from "../dialogs";
import { announce, el, reason, selectField, type Choice } from "../dom";
import { wording } from "../language/language";

const NEW = "new";

/** What `facts` make of a description. */
export const withFacts = (description: string, facts: string[]): string => [...(description.trim() ? [description.trim()] : []), ...facts].join("\n");

/** Adds `facts` to the persona chosen, or to a new one named as the account, and answers its name. */
async function addTo(choice: Persona | null, facts: string[]): Promise<string> {
  if (choice) return (await changePersona(choice.id, { description: withFacts(choice.description, facts) })).name;
  const name = await account().then(
    (who) => who.name.trim() || wording("interview-persona-you"),
    () => wording("interview-persona-you"), // No account's name to be had: the persona is named all the same.
  );
  return (await createPersona({ name, description: withFacts("", facts) })).name;
}

/** Offers `facts`; a failure says so and adds nothing. */
export async function offerPersona(facts: string[]): Promise<void> {
  if (facts.length === 0) return;
  let personas: Persona[];
  try {
    personas = await listPersonas();
  } catch (error) {
    announce(reason(error));
    return;
  }
  const used = personas.find((one) => one.is_default);
  let chosen = used ? String(used.id) : personas[0] ? String(personas[0].id) : NEW;
  const label = (one: Persona) => (one.is_default ? wording("interview-persona-in-use", { persona: one.name }) : one.name);
  const choices: Choice[] = [...personas.map((one) => ({ value: String(one.id), label: label(one) })), { value: NEW, label: wording("interview-persona-new") }];
  const picked = selectField(choices, chosen, (value) => (chosen = value), { id: "interview-persona", wide: true });
  const ticks = facts.map((fact) => ({ fact, box: el("input", { type: "checkbox", checked: true }) }));
  const add = el("button", { type: "button", className: "btn btn-primary" }, wording("interview-persona-add"));
  const notNow = el("button", { type: "button", className: "btn btn-secondary" }, wording("interview-persona-not-now"));
  const lines = ticks.map(({ fact, box }) => {
    box.onchange = () => (add.disabled = !ticks.some((one) => one.box.checked));
    return el("label", { className: "flex ai-c g-10" }, box, fact);
  });
  const shut = dialog(
    document.body,
    wording("interview-persona-title"),
    el("div", { className: "flex f-col g-16" }, el("div", { className: "flex f-col g-8" }, ...lines), el("div", { className: "fld" }, el("label", { className: "label", htmlFor: "interview-persona" }, wording("interview-persona-field")), picked.node)),
    el("div", { className: "dfoot" }, notNow, add),
  );
  notNow.onclick = () => shut.close();
  add.onclick = () => {
    add.disabled = true;
    const persona = personas.find((one) => String(one.id) === chosen) ?? null;
    const given = ticks.filter((one) => one.box.checked).map((one) => one.fact);
    void addTo(persona, given).then(
      (name) => {
        shut.close();
        announce(wording("interview-persona-added", { persona: name }));
      },
      (error: unknown) => {
        add.disabled = false;
        announce(reason(error));
      },
    );
  };
}
