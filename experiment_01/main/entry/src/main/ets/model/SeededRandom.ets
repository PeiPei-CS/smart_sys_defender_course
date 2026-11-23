export class SeededRandom {
  private state: number;
  constructor(seed: number) { this.state = seed >>> 0; if (this.state === 0) this.state = 1; }
  next(): number { this.state = (Math.imul(this.state, 1664525) + 1013904223) >>> 0; return this.state / 4294967296; }
  normal(): number { const u = Math.max(this.next(), 1e-12); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * this.next()); }
}
