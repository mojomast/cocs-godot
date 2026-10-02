// Tests opt into revision 2; the preserved functional checkpoint is the default.
const candidate=await import(process.env.HELIX_ARCHITECTURE==='2'?'./recipe-v2.mjs':'./recipe.mjs');
export const {recipe,makeRecipe,hash,polar,ID}=candidate;
