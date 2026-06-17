/**
 * 玩家枚举
 */
export enum Player {
  EMPTY = 0,
  BLACK = 1,
  WHITE = 2
}

// 【新增】定义落子位置接口，解决匿名对象报错
export interface MovePos {
  row: number;
  col: number;
}

/**
 * 游戏状态管理类
 */
export class GameState {
  private board: Array<Array<number>> = [];
  private currentPlayer: Player = Player.BLACK;
  private gameOver: boolean = false;
  private winner: Player = Player.EMPTY;
  private readonly boardSize: number = 15;
  private lastMoveRow: number = -1;
  private lastMoveCol: number = -1;

  constructor() {
    this.initBoard();
  }

  private initBoard(): void {
    this.board = [];
    for (let i: number = 0; i < this.boardSize; i++) {
      const row: Array<number> = [];
      for (let j: number = 0; j < this.boardSize; j++) {
        row.push(Player.EMPTY);
      }
      this.board.push(row);
    }
    this.currentPlayer = Player.BLACK;
    this.gameOver = false;
    this.winner = Player.EMPTY;
    this.lastMoveRow = -1;
    this.lastMoveCol = -1;
  }

  public getBoard(): Array<Array<number>> {
    return this.board;
  }

  public getBoardSize(): number {
    return this.boardSize;
  }

  public getCurrentPlayer(): Player {
    return this.currentPlayer;
  }

  public isGameOver(): boolean {
    return this.gameOver;
  }

  public getWinner(): Player {
    return this.winner;
  }

  // 【修改】使用定义好的 MovePos 接口，彻底消除报错
  public getLastMove(): MovePos | null {
    if (this.lastMoveRow === -1) {
      return null;
    }
    return { row: this.lastMoveRow, col: this.lastMoveCol };
  }

  public makeMove(row: number, col: number): boolean {
    if (this.gameOver || row < 0 || row >= this.boardSize || col < 0 || col >= this.boardSize) {
      return false;
    }
    if (this.board[row][col] !== Player.EMPTY) {
      return false;
    }

    this.board[row][col] = this.currentPlayer;
    this.lastMoveRow = row;
    this.lastMoveCol = col;

    if (this.checkWin(row, col)) {
      this.gameOver = true;
      this.winner = this.currentPlayer;
    } else {
      this.currentPlayer = this.currentPlayer === Player.BLACK ? Player.WHITE : Player.BLACK;
    }

    return true;
  }

  private checkWin(row: number, col: number): boolean {
    const directions: Array<Array<number>> = [
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1]
    ];

    for (let d: number = 0; d < directions.length; d++) {
      const dir: Array<number> = directions[d];
      let count: number = 1;
      count += this.countInDirection(row, col, dir[0], dir[1]);
      count += this.countInDirection(row, col, -dir[0], -dir[1]);
      if (count >= 5) {
        return true;
      }
    }
    return false;
  }

  private countInDirection(row: number, col: number, dRow: number, dCol: number): number {
    const player: number = this.board[row][col];
    let count: number = 0;
    let r: number = row + dRow;
    let c: number = col + dCol;

    while (r >= 0 && r < this.boardSize && c >= 0 && c < this.boardSize && this.board[r][c] === player) {
      count++;
      r += dRow;
      c += dCol;
    }
    return count;
  }

  public restart(): void {
    this.initBoard();
  }
}