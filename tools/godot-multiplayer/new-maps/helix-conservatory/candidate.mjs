// Revision 2 is production. Explicit revision 1 retains historical reproduction.
const candidate=await import(process.env.HELIX_ARCHITECTURE==='1'?'./recipe.mjs':'./recipe-v2.mjs');
export const {recipe,makeRecipe,hash,polar,ID}=candidate;
