import { GameState, MovePos } from '../model/GameState'
import { GameBoard } from '../components/GameBoard'
import { GameNetwork, NetMessage } from '../network/GameNetwork'
import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State gameState: GameState = new GameState()
  @State mode: string = 'local'
  @State myRole: number = 1
  @State isMyTurn: boolean = true
  @State statusText: string = '本地模式'
  @State roomId: string = ''
  private network: GameNetwork = new GameNetwork()
  private checkTimer: number = -1
  private lastSentMove: MovePos | null = null

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>
    this.mode = params['mode'] || 'local'

    if (this.mode === 'local') {
      this.isMyTurn = true
      this.statusText = '本地模式'
    }
    else if (this.mode === 'create') {
      this.myRole = 1
      this.isMyTurn = true
      this.statusText = '创建房间中...'
      this.network.setServerUrl(params['serverUrl'] || '')
      this.network.setOnData((data: NetMessage): void => this.onNetworkData(data))
      this.network.createRoom().then((id: string): void => {
        this.roomId = id
        this.statusText = `房间号:${id}, 等待对手加入...`
      })
      this.startCheckTimer()
    }
    else if (this.mode === 'join') {
      this.myRole = 2
      this.isMyTurn = false
      this.roomId = params['roomId'] || ''
      this.statusText = '加入房间中...'
      this.network.setServerUrl(params['serverUrl'] || '')
      this.network.setOnData((data: NetMessage): void => this.onNetworkData(data))
      this.network.joinRoom(this.roomId).then((ok: boolean): void => {
        this.statusText = ok ? '已加入，等待房主落子...' : '加入失败'
      })
      this.startCheckTimer()
    }
  }

  aboutToDisappear(): void {
    this.network.close()
    if (this.checkTimer !== -1) {
      clearInterval(this.checkTimer)
    }
  }

  startCheckTimer(): void {
    this.checkTimer = setInterval(() => this.checkAndSendMove(), 200)
  }

  checkAndSendMove(): void {
    if (this.mode === 'local') return
    if (!this.isMyTurn) return

    let move = this.gameState.getLastMove()
    if (!move) return

    if (!this.lastSentMove || this.lastSentMove.row !== move.row || this.lastSentMove.col !== move.col) {
      this.lastSentMove = move
      this.network.send({ type: 'move', row: move.row, col: move.col })
      this.isMyTurn = false
      this.statusText = '等待对方...'

      if (this.gameState.isGameOver()) {
        this.statusText = this.gameState.getWinner() === this.myRole ? '你赢了！' : '你输了！'
      }
    }
  }

  onNetworkData(data: NetMessage): void {
    if (data.type === 'move' && data.row !== undefined && data.col !== undefined) {
      this.gameState.makeMove(data.row, data.col)
      this.isMyTurn = true
      this.statusText = '轮到你了'
      if (this.gameState.isGameOver()) {
        this.statusText = this.gameState.getWinner() === this.myRole ? '你赢了！' : '你输了！'
      }
    }
  }

  build() {
    Column() {
      Row() {
        Text('五子棋').fontSize(28).fontWeight(FontWeight.Bold)
        Text(this.statusText).fontSize(14).margin({ left: 15 }).fontColor('#666')
      }
      .width('100%').height(60).padding({ left: 20, right: 20 }).backgroundColor('#F5F5F5')

      if (this.mode !== 'local') {
        Text(`房间: ${this.roomId} | 你是: ${this.myRole === 1 ? '黑棋' : '白棋'}`)
          .fontSize(14).margin(10).fontColor('#333')
      }

      Column() {
        GameBoard({ gameState: $gameState })
          .width('100%').margin({ top: 20, bottom: 20 })
      }
      .width('100%').height('80%').justifyContent(FlexAlign.Center)
    }
    .width('100%').height('100%').backgroundColor('#FFFFFF')
  }
}