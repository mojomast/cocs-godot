// Source `emit` payloads can replace id; serial also allocates entities. Track
// retained OBJECT identity, publish every event once with a finite wire ordinal.
// sourceId preserves the source payload ID; snapshots are never rewritten.
export class EventCursor {
  constructor() { this.previous = null; this.ordinal = 0; }
  take(match) {
    const ring = match.events;
    const start = this.previous === null ? 0 : ring.indexOf(this.previous) + 1;
    if (this.previous !== null && start === 0) throw new Error('Source event ring cursor lost');
    const batch = ring.slice(start).map(event => {
      if (!Number.isSafeInteger(this.ordinal + 1)) throw new Error('Event ordinal exhausted');
      return {...event, sourceId:event.id, id:++this.ordinal};
    });
    if (ring.length) this.previous = ring.at(-1);
    return batch;
  }
}
