# リアルタイム・アクティブバトル(RTAB) Ver 1.16
# 配布元・サポートURL
# http://members.jcom.home.ne.jp/cogwheel/

class Scene_Battle
  #--------------------------------------------------------------------------
  # ● 公開インスタンス変数
  #--------------------------------------------------------------------------
  attr_reader   :status_window            # ステータスウィンドウ
  attr_reader   :spriteset                # バトルスプライト
  attr_reader   :scroll_time              # スクリーン移動基本時間
  attr_reader   :zoom_rate                # 敵バトラー基本位置
  attr_reader   :drive                    # カメラ駆動
  attr_accessor :force                    # アクション強制度
  attr_accessor :camera                   # 現在のカメラ所持者
  #--------------------------------------------------------------------------
  # ● ATB基礎セットアップ
  #--------------------------------------------------------------------------
  def atb_setup
    # ATB初期化
    # speed   : バトルスピード決定。値が小さいほど早い
    # @active : アクティブ度設定
    #           3 : 常にアクティブ状態
    #           2 : スキル・アイテム選択中のみアクティブゲージが止まる
    #           1 : 2の状態に加え、ターゲット選択時もウェイトが掛かる
    #           0 : 1の状態に加え、コマンド入力時にもウェイトが掛かる
    # @action : 他人が行動中に自分も行動を起こすことを許すか
    #           3 : 自分が行動不能でない限り限り許す
    #           2 : 自分がダメージを受けていない限り許す
    #           1 : 2の状態に加え、ターゲットが行動していない限り許す
    #           0 : 行動を許さない。順番に行動し終えるまで待つ
    # @anime_wait : trueにするとバトルアニメ・ダメージ表示中はウェイトが掛かる
    # @damage_wait : ダメージ表示待ち時間（単位はフレーム）
    # @after_wait : 味方・敵全滅時、次の処理に移るまでの待ち時間
    #               [a, b] a は味方全滅時、b は敵全滅時（単位はフレーム）
    # @enemy_speed : 敵の思考速度。1なら即時行動。
    #                1フレーム毎に、1/@enemy_speedの確率で行動を起こす
    # @force : 強制アクションでスキル使用時の強制具合
    #          2:スキルは全て詠唱せず、必ず即時実行
    #          1:単独スキルは詠唱し、連携スキルのみ即時実行
    #          0:全スキル詠唱を行うだけ
    # ($scene.force = x とすることにより、通常イベントのスクリプトから変更可能）
    # @drive : カメラ駆動ON/OFF。trueで駆動ON、falseで駆動OFF
    # @scroll_time : スクリーン移動に要する基本時間
    # @zoom_rate = [i, j] : エネミーのズーム率
    #                       i が画面最上部に配置した時の拡大率
    #                       j が画面最下部に配置した時の拡大率
    #                       1 倍としたいときも、1.0 と必ず小数で設定すること
    speed = 150
    @active = 1
    @action = 2
    @anime_wait = false
    @damage_wait = 10
    @after_wait = [80, 0]
    @enemy_speed = 40
    @force = 2
    @drive = true
    @scroll_time = 15
    @zoom_rate = [0.2, 1.0]
    @help_time = 40
    @escape == false
    @camera = nil
    @max = 0
    @turn_cnt = 0
    @help_wait = 0
    @action_battlers = []
    @synthe = []
    @spell_p = {}
    @spell_e = {}
    @command_a = false
    @command = []
    @party = false
    for battler in $game_party.actors + $game_troop.enemies
      spell_reset(battler)
      battler.at = battler.agi * rand(speed / 2)
      battler.damage_pop = {}
      battler.damage = {}
      battler.damage_sp = {}
      battler.critical = {}
      battler.recover_hp = {}
      battler.recover_sp = {}
      battler.state_p = {}
      battler.state_m = {}
      battler.animation = []
      if battler.is_a?(Game_Actor)
        @max += battler.agi
      end
    end
    @max *= speed
    @max /= $game_party.actors.size
    for battler in $game_party.actors + $game_troop.enemies
      battler.atp = 100 * battler.at / @max
    end
  end
  #--------------------------------------------------------------------------
  # ● ATゲージMax時SE
  #--------------------------------------------------------------------------
  def fullat_se
    Audio.se_play("Audio/SE/033-switch02", 80, 100)
  end
  #--------------------------------------------------------------------------
  # ● レベルアップSE
  #--------------------------------------------------------------------------
  def levelup_se
    Audio.se_play("Audio/SE/056-Right02", 80, 100)
  end
  #--------------------------------------------------------------------------
  # ● スキル習得SE
  #--------------------------------------------------------------------------
  def skill_se
    Audio.se_play("Audio/SE/056-Right02", 80, 150)
  end
end

class Window_Base < Window
  #--------------------------------------------------------------------------
  # ● ATG の描画
  #     actor : アクター
  #     x     : 描画先 X 座標
  #     y     : 描画先 Y 座標
  #     width : 描画先の幅
  #--------------------------------------------------------------------------
  def draw_actor_atg(actor, x, y, width = 144)
    if @at_gauge == nil
      # plus_x:X座標の位置補正 rate_x:X座標の位置補正(%) plus_y:Y座標の位置補正
      # plus_width:幅の補正 rate_width:幅の補正(%) height:縦幅
      # align1:描画タイプ1 0:左詰め 1:中央揃え 2:右詰め
      # align2:描画タイプ2 0:上詰め 1:中央揃え 2:下詰め
      # align3:ゲージタイプ 0:左詰め 1:右詰め
      @plus_x = 0
      @rate_x = 0
      @plus_y = 16
      @plus_width = 0
      @rate_width = 100
      @width = @plus_width + width * @rate_width / 100
      @height = 16
      @align1 = 0
      @align2 = 1
      @align3 = 0
      # グラデーション設定 grade1:空ゲージ grade2:実ゲージ
      # (0:横にグラデーション 1:縦にグラデーション 2:斜めにグラデーション）
      grade1 = 1
      grade2 = 0
      # 色設定。color1:最外枠，color2:中枠
      # color3:空枠ダークカラー，color4:空枠ライトカラー
      color1 = Color.new(0, 0, 0)
      color2 = Color.new(255, 255, 192)
      color3 = Color.new(0, 0, 0, 192)
      color4 = Color.new(0, 0, 64, 192)
      # ゲージの色設定
      # 通常時の色設定
      color5 = Color.new(0, 64, 80)
      color6 = Color.new(0, 128, 160)
      # ゲージがMAXの時の色設定
      color7 = Color.new(80, 0, 0)
      color8 = Color.new(240, 0, 0)
      # 連携スキル使用時の色設定
      color9 = Color.new(80, 64, 32)
      color10 = Color.new(240, 192, 96)
      # スキル詠唱時の色設定
      color11 = Color.new(80, 0, 64)
      color12 = Color.new(240, 0, 192)
      # ゲージの描画
      gauge_rect_at(@width, @height, @align3, color1, color2,
                  color3, color4, color5, color6, color7, color8,
                  color9, color10, color11, color12, grade1, grade2)
    end
    # 変数atに描画するゲージの幅を代入
    if actor.rtp == 0
      at = (width + @plus_width) * actor.atp * @rate_width / 10000
    else
      at = (width + @plus_width) * actor.rt * @rate_width / actor.rtp / 100
    end
    if at > width
      at = width
    end
    # ゲージの左詰・中央構え等の補正
    case @align1
    when 1
      x += (@rect_width - width) / 2
    when 2
      x += @rect_width - width
    end
    case @align2
    when 1
      y -= @height / 2
    when 2
      y -= @height
    end
    self.contents.blt(x + @plus_x + width * @rate_x / 100, y + @plus_y,
                      @at_gauge, Rect.new(0, 0, @width, @height))
    if @align3 == 0
      rect_x = 0
    else
      x += @width - at - 1
      rect_x = @width - at - 1
    end
    # ゲージの色設定
    if at == width
        # MAX時のゲージ描画
      self.contents.blt(x + @plus_x + @width * @rate_x / 100, y + @plus_y,
                        @at_gauge, Rect.new(rect_x, @height * 2, at, @height))
    else
      if actor.rtp == 0
        # 通常時のゲージ描画
        self.contents.blt(x + @plus_x + @width * @rate_x / 100, y + @plus_y,
                          @at_gauge, Rect.new(rect_x, @height, at, @height))
      else
        if actor.spell == true
          # 連携スキル使用時のゲージ描画
          self.contents.blt(x + @plus_x + @width * @rate_x / 100, y + @plus_y,
                        @at_gauge, Rect.new(rect_x, @height * 3, at, @height))
        else
          # スキル詠唱時のゲージ描画
          self.contents.blt(x + @plus_x + @width * @rate_x / 100, y + @plus_y,
                        @at_gauge, Rect.new(rect_x, @height * 4, at, @height))
        end
      end
    end
  end
end

#==============================================================================
# ■ Scene_Battle (分割定義 1)
#------------------------------------------------------------------------------
# 　バトル画面の処理を行うクラスです。
#==============================================================================

class Scene_Battle
  #--------------------------------------------------------------------------
  # ● メイン処理
  #--------------------------------------------------------------------------
  def main
    # 戦闘用の各種一時データを初期化
    $game_temp.in_battle = true
    $game_temp.battle_turn = 0
    $game_temp.battle_event_flags.clear
    $game_temp.battle_abort = false
    $game_temp.battle_main_phase = false
    $game_temp.battleback_name = $game_map.battleback_name
    $game_temp.forcing_battler = nil
    # バトルイベント用インタプリタを初期化
    $game_system.battle_interpreter.setup(nil, 0)
    # トループを準備
    @troop_id = $game_temp.battle_troop_id
    $game_troop.setup(@troop_id)
    atb_setup
    # アクターコマンドウィンドウを作成
    s1 = $data_system.words.attack
    s2 = $data_system.words.skill
    s3 = $data_system.words.guard
    s4 = $data_system.words.item
    @actor_command_window = Window_Command.new(160, [s1, s2, s3, s4])
    @actor_command_window.y = 160
    @actor_command_window.back_opacity = 160
    @actor_command_window.active = false
    @actor_command_window.visible = false
    # その他のウィンドウを作成
    @party_command_window = Window_PartyCommand.new
    @help_window = Window_Help.new
    @help_window.back_opacity = 160
    @help_window.visible = false
    @status_window = Window_BattleStatus.new
    @message_window = Window_Message.new
    # スプライトセットを作成
    @spriteset = Spriteset_Battle.new
    # ウェイトカウントを初期化
    @wait_count = 0
    # トランジション実行
    if $data_system.battle_transition == ""
      Graphics.transition(20)
    else
      Graphics.transition(40, "Graphics/Transitions/" +
        $data_system.battle_transition)
    end
    # プレバトルフェーズ開始
    start_phase1
    # メインループ
    loop do
      # ゲーム画面を更新
      Graphics.update
      # 入力情報を更新
      Input.update
      # フレーム更新
      update
      # 画面が切り替わったらループを中断
      if $scene != self
        break
      end
    end
    # マップをリフレッシュ
    $game_map.refresh
    # トランジション準備
    Graphics.freeze
    # ウィンドウを解放
    @actor_command_window.dispose
    @party_command_window.dispose
    @help_window.dispose
    @status_window.dispose
    @message_window.dispose
    if @skill_window != nil
      @skill_window.dispose
    end
    if @item_window != nil
      @item_window.dispose
    end
    if @result_window != nil
      @result_window.dispose
    end
    # スプライトセットを解放
    @spriteset.dispose
    # タイトル画面に切り替え中の場合
    if $scene.is_a?(Scene_Title)
      # 画面をフェードアウト
      Graphics.transition
      Graphics.freeze
    end
    # 戦闘テストからゲームオーバー画面以外に切り替え中の場合
    if $BTEST and not $scene.is_a?(Scene_Gameover)
      $scene = nil
    end
  end
  #--------------------------------------------------------------------------
  # ● 勝敗判定
  #--------------------------------------------------------------------------
  def judge
    # 全滅判定が真、またはパーティ人数が 0 人の場合
    if $game_party.all_dead? or $game_party.actors.size == 0
      # 敗北可能の場合
      if $game_temp.battle_can_lose
        # バトル開始前の BGM に戻す
        $game_system.bgm_play($game_temp.map_bgm)
        # バトル終了
        battle_end(2)
        # true を返す
        return true
      end
      # ゲームオーバーフラグをセット
      $game_temp.gameover = true
      # true を返す
      return true
    end
    # エネミーが 1 体でも存在すれば false を返す
    for enemy in $game_troop.enemies
      if enemy.exist?
        return false
      end
    end
    # アフターバトルフェーズ開始 (勝利)
    start_phase5
    # true を返す
    return true
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新
  #--------------------------------------------------------------------------
  def update
    # バトルイベント実行中の場合
    if $game_system.battle_interpreter.running?
      if @command.size > 0
        @command_a = false
        @command = []
        command_delete
      end
      @status_window.at_refresh
      # インタプリタを更新
      $game_system.battle_interpreter.update
      # アクションを強制されているバトラーが存在しない場合
      if $game_temp.forcing_battler == nil
        # バトルイベントの実行が終わった場合
        unless $game_system.battle_interpreter.running?
          # バトルイベントのセットアップを再実行
          @status_window.refresh
          setup_battle_event
        end
      end
    end
    # システム (タイマー)、画面を更新
    $game_system.update
    $game_screen.update
    # タイマーが 0 になった場合
    if $game_system.timer_working and $game_system.timer == 0
      # バトル中断
      $game_temp.battle_abort = true
    end
    # ウィンドウを更新
    @help_window.update
    @party_command_window.update
    @actor_command_window.update
    @status_window.update
    @message_window.update
    # スプライトセットを更新
    @spriteset.update
    # トランジション処理中の場合
    if $game_temp.transition_processing
      # トランジション処理中フラグをクリア
      $game_temp.transition_processing = false
      # トランジション実行
      if $game_temp.transition_name == ""
        Graphics.transition(20)
      else
        Graphics.transition(40, "Graphics/Transitions/" +
          $game_temp.transition_name)
      end
    end
    # メッセージウィンドウ表示中の場合
    if $game_temp.message_window_showing
      return
    end
    # ゲームオーバーの場合
    if $game_temp.gameover
      # ゲームオーバー画面に切り替え
      $scene = Scene_Gameover.new
      return
    end
    # タイトル画面に戻す場合
    if $game_temp.to_title
      # タイトル画面に切り替え
      $scene = Scene_Title.new
      return
    end
    # バトル中断の場合
    if $game_temp.battle_abort
      # バトル開始前の BGM に戻す
      $game_system.bgm_play($game_temp.map_bgm)
      # バトル終了
      battle_end(1)
      return
    end
    # ヘルプウィンドウ表示中の場合
    if @help_wait > 0
      @help_wait -= 1
      if @help_wait == 0
        # ヘルプウィンドウを隠す
        @help_window.visible = false
      end
    end
    # アクションを強制されているバトラーが存在せず、
    # かつバトルイベントが実行中の場合
    if $game_temp.forcing_battler == nil and
       $game_system.battle_interpreter.running?
      return
    end
    # フェーズによって分岐
    case @phase
    when 0  # ATゲージ更新フェーズ
      if anime_wait_return
        update_phase0
      end
    when 1  # プレバトルフェーズ
      update_phase1
      return
    when 2  # パーティコマンドフェーズ
      update_phase2
      return
    when 5  # アフターバトルフェーズ
      update_phase5
      return
    end
    if $scene != self
      return
    end
    if @phase == 0
      if @command.size != 0  # アクターコマンドフェーズ
        if @command_a == false
          start_phase3
        end
        update_phase3
      end
      # ウェイト中の場合
      if @wait_count > 0
        # ウェイトカウントを減らす
        @wait_count -= 1
        return
      end
      update_phase4
    end
  end

#==============================================================================
# ■ Scene_Battle (分割定義 2)
#------------------------------------------------------------------------------
# 　バトル画面の処理を行うクラスです。
#==============================================================================

  #--------------------------------------------------------------------------
  # ● フレーム更新 (ATゲージ更新フェーズ)
  #--------------------------------------------------------------------------
  def update_phase0
    if $game_temp.battle_turn == 0
      $game_temp.battle_turn = 1
    end
    # B ボタンが押された場合
    if @command_a == false and @party == false
      if Input.trigger?(Input::B)
        # キャンセル SE を演奏
        $game_system.se_play($data_system.cancel_se)
        @party = true
      end
    end
    if @party == true and
        ((@action > 0 and @action_battlers.empty?) or (@action == 0 and 
        (@action_battlers.empty? or @action_battlers[0].phase == 1)))
      # パーティコマンドフェーズへ
      start_phase2
      return
    end
    # ATゲージ増加処理
    cnt = 0
    for battler in $game_party.actors + $game_troop.enemies
      active?(battler)
      if battler.rtp == 0
        if battler.at >= @max
          if battler.is_a?(Game_Actor)
            if battler.inputable?
              unless @action_battlers.include?(battler) or
                  @command.include?(battler) or @escape == true
                if battler.current_action.forcing
                  fullat_se
                  force_action(battler)
                  action_start(battler)
                else
                  fullat_se
                  @command.push(battler)
                end
              end
            else
              unless @action_battlers.include?(battler) or
                      battler == @command[0]
                battler.current_action.clear
                if @command.include?(battler)
                  @command.delete(battler)
                else
                  if battler.movable?
                    fullat_se
                  end
                end
                action_start(battler)
              end
            end
          else
            unless @action_battlers.include?(battler)
              if battler.current_action.forcing
                force_action(battler)
                action_start(battler)
              else
                if @enemy_speed != 0
                  if rand(@enemy_speed) == 0
                    number = cnt - $game_party.actors.size
                    enemy_action(number)
                  end
                else
                  number = cnt - $game_party.actors.size
                  enemy_action(number)
                end
              end
            end
          end
        else
          battler.at += battler.agi
          if battler.guarding?
            battler.at += battler.agi
          end
          if battler.movable?
            battler.atp = 100 * battler.at / @max
          end
        end
      else
        if battler.rt >= battler.rtp
          speller = synthe?(battler)
          if speller != nil
            battler = speller[0]
          end
          unless @action_battlers.include?(battler)
            if battler.is_a?(Game_Actor)
              fullat_se
            end
            battler.rt = battler.rtp
            action_start(battler)
          end
        else
          battler.rt += battler.agi
          speller = synthe?(battler)
          if speller != nil
            for spell in speller
              if spell != battler
                spell.rt += battler.agi
              end
            end
          end
        end
      end
      cnt += 1
    end
    # ATゲージをリフレッシュ
    @status_window.at_refresh
    # 逃走処理
    if @escape == true and
        ((@action > 0 and @action_battlers.empty?) or (@action == 0 and 
        (@action_battlers.empty? or @action_battlers[0].phase == 1)))
      temp = false
      for battler in $game_party.actors
        if battler.inputable?
          temp = true
        end
      end
      if temp == true
        for battler in $game_party.actors
          if battler.at < @max and battler.inputable?
            temp = false
            break
          end
        end
        if temp == true
          @escape = false
          for battler in $game_party.actors
            battler.at %= @max
          end
          $game_temp.battle_main_phase = false
          update_phase2_escape
        end
      end
    end
  end
  #--------------------------------------------------------------------------
  # ● パーティコマンドフェーズ開始
  #--------------------------------------------------------------------------
  def start_phase2
    # フェーズ 2 に移行
    @phase = 2
    @party = false
    # パーティコマンドウィンドウを有効化
    @party_command_window.active = true
    @party_command_window.visible = true
    # アクターを非選択状態に設定
    @actor_index = -1
    # アクターコマンドウィンドウを無効化
    @actor_command_window.active = false
    @actor_command_window.visible = false
    if @command.size != 0
      # アクターの明滅エフェクト OFF
      if @active_actor != nil
        @active_actor.blink = false
      end
    end
    # カメラセット
    @camera == "party"
    @spriteset.screen_target(0, 0, 1)
    # メインフェーズフラグをクリア
    $game_temp.battle_main_phase = false
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (パーティコマンドフェーズ)
  #--------------------------------------------------------------------------
  def update_phase2
    # C ボタンが押された場合
    if Input.trigger?(Input::C)
      # パーティコマンドウィンドウのカーソル位置で分岐
      case @party_command_window.index
      when 0  # 戦う
        # パーティコマンドウィンドウを無効化
        @party_command_window.active = false
        @party_command_window.visible = false
        # 決定 SE を演奏
        $game_system.se_play($data_system.decision_se)
        @escape = false
        @phase = 0
        if $game_temp.battle_turn == 0
          $game_temp.battle_turn = 1
        end
        if @command_a == true
          # アクターコマンドフェーズ開始
          start_phase3
        else
          $game_temp.battle_main_phase = true
        end
      when 1  # 逃げる
        # 逃走可能ではない場合
        if $game_temp.battle_can_escape == false
          # ブザー SE を演奏
          $game_system.se_play($data_system.buzzer_se)
          return
        end
        # 決定 SE を演奏
        $game_system.se_play($data_system.decision_se)
        @phase = 0
        # パーティコマンドウィンドウを無効化
        @party_command_window.active = false
        @party_command_window.visible = false
        $game_temp.battle_main_phase = true
        if $game_temp.battle_turn == 0
          update_phase2_escape
          $game_temp.battle_turn = 1
          for battler in $game_party.actors
            battler.at -= @max / 2
          end
          return
        end
        # 決定 SE を演奏
        $game_system.se_play($data_system.decision_se)
        @escape = true
        for battler in $game_party.actors
          @command_a = false
          @command.delete(battler)
          @action_battlers.delete(battler)
          skill_reset(battler)
        end
      end
      return
    end
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (パーティコマンドフェーズ : 逃げる)
  #--------------------------------------------------------------------------
  def update_phase2_escape
    # エネミーの素早さ平均値を計算
    enemies_agi = 0
    enemies_number = 0
    for enemy in $game_troop.enemies
      if enemy.exist?
        enemies_agi += enemy.agi
        enemies_number += 1
      end
    end
    if enemies_number > 0
      enemies_agi /= enemies_number
    end
    # アクターの素早さ平均値を計算
    actors_agi = 0
    actors_number = 0
    for actor in $game_party.actors
      if actor.exist?
        actors_agi += actor.agi
        actors_number += 1
      end
    end
    if actors_number > 0
      actors_agi /= actors_number
    end
    # 逃走成功判定
    success = rand(100) < 50 * actors_agi / enemies_agi
    # 逃走成功の場合
    if success
      # 逃走 SE を演奏
      $game_system.se_play($data_system.escape_se)
      # バトル開始前の BGM に戻す
      $game_system.bgm_play($game_temp.map_bgm)
      # バトル終了
      battle_end(1)
    # 逃走失敗の場合
    else
      @help_window.set_text("逃走失敗", 1)
      @help_wait = @help_time
      # パーティ全員のアクションをクリア
      $game_party.clear_actions
      # メインフェーズ開始
      start_phase4
    end
  end
  #--------------------------------------------------------------------------
  # ● アフターバトルフェーズ開始
  #--------------------------------------------------------------------------
  def start_phase5
    # フェーズ 5 に移行
    @phase = 5
    # バトル終了 ME を演奏
    $game_system.me_play($game_system.battle_end_me)
    # バトル開始前の BGM に戻す
    $game_system.bgm_play($game_temp.map_bgm)
    # EXP、ゴールド、トレジャーを初期化
    exp = 0
    gold = 0
    treasures = []
    if @active_actor != nil
      @active_actor.blink = false
    end
    # メインフェーズフラグをセット
    $game_temp.battle_main_phase = true
    # パーティコマンドウィンドウを無効化
    @party_command_window.active = false
    @party_command_window.visible = false
    # アクターコマンドウィンドウを無効化
    @actor_command_window.active = false
    @actor_command_window.visible = false
    if @skill_window != nil
      # スキルウィンドウを解放
      @skill_window.dispose
      @skill_window = nil
    end
    if @item_window != nil
      # アイテムウィンドウを解放
      @item_window.dispose
      @item_window = nil
    end
    # ヘルプウィンドウを隠す
    @help_window.visible = false if @help_wait == 0
    # ループ
    for enemy in $game_troop.enemies
      # エネミーが隠れ状態でない場合
      unless enemy.hidden
        # 獲得 EXP、ゴールドを追加
        exp += enemy.exp
        gold += enemy.gold
        # トレジャー出現判定
        if rand(100) < enemy.treasure_prob
          if enemy.item_id > 0
            treasures.push($data_items[enemy.item_id])
          end
          if enemy.weapon_id > 0
            treasures.push($data_weapons[enemy.weapon_id])
          end
          if enemy.armor_id > 0
            treasures.push($data_armors[enemy.armor_id])
          end
        end
      end
    end
    # トレジャーの数を 6 個までに限定
    treasures = treasures[0..5]
    # EXP 獲得
    for i in 0...$game_party.actors.size
      actor = $game_party.actors[i]
      if actor.cant_get_exp? == false
        last_level = actor.level
        actor.exp += exp
        if actor.level > last_level
          @status_window.level_up(i)
          actor.damage[[actor, -1]] = "Level up!"
          actor.up_level = actor.level - last_level
        end
      end
    end
    # ゴールド獲得
    $game_party.gain_gold(gold)
    # トレジャー獲得
    for item in treasures
      case item
      when RPG::Item
        $game_party.gain_item(item.id, 1)
      when RPG::Weapon
        $game_party.gain_weapon(item.id, 1)
      when RPG::Armor
        $game_party.gain_armor(item.id, 1)
      end
    end
    # バトルリザルトウィンドウを作成
    @result_window = Window_BattleResult.new(exp, gold, treasures)
    # ウェイトカウントを設定
    @phase5_wait_count = 100
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (アフターバトルフェーズ)
  #--------------------------------------------------------------------------
  def update_phase5
    # ウェイトカウントが 0 より大きい場合
    if @phase5_wait_count > 0
      # ウェイトカウントを減らす
      @phase5_wait_count -= 1
      # ウェイトカウントが 0 になった場合
      if @phase5_wait_count == 0
        # リザルトウィンドウを表示
        @result_window.visible = true
        # メインフェーズフラグをクリア
        $game_temp.battle_main_phase = false
        # ステータスウィンドウをリフレッシュ
        @status_window.refresh
        for actor in $game_party.actors
          if actor.damage.include?([actor, 0])
            @phase5_wait_count = 20
            actor.damage_pop[[actor, 0]] = true
          end
          if actor.damage.include?([actor, -1])
            @phase5_wait_count = 20
            actor.damage_pop[[actor, -1]] = true
            for level in actor.level - actor.up_level + 1..actor.level
              for skill in $data_classes[actor.class_id].learnings
                if level == skill.level and not actor.skill_learn?(skill.id)
                  actor.damage[[actor, 0]] = "New Skill!"
                  break
                end
              end
            end
          end
        end
      end
      return
    end
    # C ボタンが押された場合
    if Input.trigger?(Input::C)
      # バトル終了
      battle_end(0)
    end
  end

#==============================================================================
# ■ Scene_Battle (分割定義 3)
#------------------------------------------------------------------------------
# 　バトル画面の処理を行うクラスです。
#==============================================================================

  #--------------------------------------------------------------------------
  # ● アクターコマンドフェーズ開始
  #--------------------------------------------------------------------------
  def start_phase3
    if victory?
      return
    end
    # メインフェーズフラグをクリア
    $game_temp.battle_main_phase = false
    @command_a = true
    @active_actor = @command[0]
    cnt = 0
    for actor in $game_party.actors
      if actor == @active_actor
        @actor_index = cnt
      end
      cnt += 1
    end
    @active_actor.blink = true
    unless @active_actor.inputable?
      @active_actor.current_action.clear
      phase3_next_actor
      return
    end
    phase3_setup_command_window
    # カメラの設定
    @camera = "command"
    plus = ($game_party.actors.size - 1) / 2.0 - @actor_index
    y = [(plus.abs - 1.5) * 10 , 0].min
    @spriteset.screen_target(plus * 50, y, 1.0 + y * 0.002)
  end
  #--------------------------------------------------------------------------
  # ● アクターのコマンド入力終了
  #--------------------------------------------------------------------------
  def phase3_next_actor
    @command.shift
    @command_a = false
    # メインフェーズフラグをセット
    $game_temp.battle_main_phase = true
    # アクターコマンドウィンドウを無効化
    @actor_command_window.active = false
    @actor_command_window.visible = false
    # アクターの明滅エフェクト OFF
    if @active_actor != nil
      @active_actor.blink = false
    end
    action_start(@active_actor)
    # カメラを元に戻す
    if @camera == "command"
      @spriteset.screen_target(0, 0, 1)
    end
    return
  end
  #--------------------------------------------------------------------------
  # ● アクターコマンドウィンドウのセットアップ
  #--------------------------------------------------------------------------
  def phase3_setup_command_window
    # パーティコマンドウィンドウを無効化
    @party_command_window.active = false
    @party_command_window.visible = false
    # アクターコマンドウィンドウを有効化
    @actor_command_window.active = true
    @actor_command_window.visible = true
    # アクターコマンドウィンドウの位置を設定
    @actor_command_window.x = @actor_index * 160 +
                              (4 - $game_party.actors.size) * 80
    # インデックスを 0 に設定
    @actor_command_window.index = 0
  end
  #--------------------------------------------------------------------------
  # ● エネミーアクション作成
  #--------------------------------------------------------------------------
  def enemy_action(number)
    enemy = $game_troop.enemies[number]
    unless enemy.current_action.forcing
      enemy.make_action
    end
    action_start(enemy)
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (アクターコマンドフェーズ)
  #--------------------------------------------------------------------------
  def update_phase3
    if victory? and @command_a
      command_delete
      @command.push(@active_actor)
      return
    end
    # エネミーアローが有効の場合
    if @enemy_arrow != nil
      update_phase3_enemy_select
    # アクターアローが有効の場合
    elsif @actor_arrow != nil
      update_phase3_actor_select
    # スキルウィンドウが有効の場合
    elsif @skill_window != nil
      update_phase3_skill_select
    # アイテムウィンドウが有効の場合
    elsif @item_window != nil
      update_phase3_item_select
    # アクターコマンドウィンドウが有効の場合
    elsif @actor_command_window.active
      update_phase3_basic_command
    end
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (アクターコマンドフェーズ : 基本コマンド)
  #--------------------------------------------------------------------------
  def update_phase3_basic_command
    unless @active_actor.inputable?
      @active_actor.current_action.clear
      phase3_next_actor
      return
    end
    # B ボタンが押された場合
    if Input.trigger?(Input::B) and @party == false
      # キャンセル SE を演奏
      $game_system.se_play($data_system.cancel_se)
      @party = true
    end
    if @party == true and
        ((@action > 0 and @action_battlers.empty?) or (@action == 0 and 
        (@action_battlers.empty? or @action_battlers[0].phase == 1)))
      # パーティコマンドフェーズへ
      start_phase2
      return
    end
    # C ボタンが押された場合
    if Input.trigger?(Input::C)
      @party = false
      # アクターコマンドウィンドウのカーソル位置で分岐
      case @actor_command_window.index
      when 0  # 攻撃
        # 決定 SE を演奏
        $game_system.se_play($data_system.decision_se)
        # エネミーの選択を開始
        start_enemy_select
      when 1  # スキル
        # 決定 SE を演奏
        $game_system.se_play($data_system.decision_se)
        # スキルの選択を開始
        start_skill_select
      when 2  # 防御
        # 決定 SE を演奏
        $game_system.se_play($data_system.decision_se)
        # アクションを設定
        @active_actor.current_action.kind = 0
        @active_actor.current_action.basic = 1
        # 次のアクターのコマンド入力へ
        phase3_next_actor
      when 3  # アイテム
        # 決定 SE を演奏
        $game_system.se_play($data_system.decision_se)
        # アイテムの選択を開始
        start_item_select
      end
      return
    end
    # キャラチェンジ
    if @command.size > 1
      # R ボタンが押された場合
      if Input.trigger?(Input::R)
        $game_system.se_play($data_system.cursor_se)
        @party = false
        # アクターの明滅エフェクト OFF
        if @active_actor != nil
          @active_actor.blink = false
        end
        @command.push(@command[0])
        @command.shift
        @command_a = false
        # 新たなコマンドウィンドウの立ち上げ
        start_phase3
      end
      # L ボタンが押された場合
      if Input.trigger?(Input::L)
        $game_system.se_play($data_system.cursor_se)
        @party = false
        # アクターの明滅エフェクト OFF
        if @active_actor != nil
          @active_actor.blink = false
        end
        @command.unshift(@command[@command.size - 1])
        @command.delete_at(@command.size - 1)
        @command_a = false
        # 新たなコマンドウィンドウの立ち上げ
        start_phase3
      end
      # 右 ボタンが押された場合
      if Input.trigger?(Input::RIGHT)
        $game_system.se_play($data_system.cursor_se)
        @party = false
        # アクターの明滅エフェクト OFF
        if @active_actor != nil
          @active_actor.blink = false
        end
        actor = $game_party.actors[@actor_index]
        while actor == @command[0] or (not @command.include?(actor))
          @actor_index += 1
          @actor_index %= $game_party.actors.size
          actor = $game_party.actors[@actor_index]
          if actor == @command[0]
            break
          end
        end
        while actor != @command[0]
          @command.push(@command.shift)
        end
        @command_a = false
        # 新たなコマンドウィンドウの立ち上げ
        start_phase3
      end
      # 左 ボタンが押された場合
      if Input.trigger?(Input::LEFT)
        $game_system.se_play($data_system.cursor_se)
        @party = false
        # アクターの明滅エフェクト OFF
        if @active_actor != nil
          @active_actor.blink = false
        end
        actor = $game_party.actors[@actor_index]
        while actor == @command[0] or (not @command.include?(actor))
          @actor_index -= 1
          @actor_index %= $game_party.actors.size
          actor = $game_party.actors[@actor_index]
          if actor == @command[0]
            break
          end
        end
        while actor != @command[0]
          @command.push(@command.shift)
        end
        @command_a = false
        # 新たなコマンドウィンドウの立ち上げ
        start_phase3
      end
    end
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (アクターコマンドフェーズ : スキル選択)
  #--------------------------------------------------------------------------
  def update_phase3_skill_select
    # コマンド選択中に行動不能になった場合
    unless @active_actor.inputable?
      @active_actor.current_action.clear
      command_delete
      # 次のアクターのコマンド入力へ
      phase3_next_actor
      return
    end
    # スキルウィンドウを可視状態にする
    @skill_window.visible = true
    # スキルウィンドウを更新
    @skill_window.update
    # B ボタンが押された場合
    if Input.trigger?(Input::B)
      # キャンセル SE を演奏
      $game_system.se_play($data_system.cancel_se)
      # スキルの選択を終了
      end_skill_select
      return
    end
    # C ボタンが押された場合
    if Input.trigger?(Input::C)
      # スキルウィンドウで現在選択されているデータを取得
      @skill = @skill_window.skill
      # 使用できない場合
      if @skill == nil or not @active_actor.skill_can_use?(@skill.id)
        # ブザー SE を演奏
        $game_system.se_play($data_system.buzzer_se)
        return
      end
      # 決定 SE を演奏
      $game_system.se_play($data_system.decision_se)
      # アクションを設定
      @active_actor.current_action.skill_id = @skill.id
      # スキルウィンドウを不可視状態にする
      @skill_window.visible = false
      # 効果範囲が敵単体の場合
      if @skill.scope == 1
        # エネミーの選択を開始
        start_enemy_select
      # 効果範囲が味方単体の場合
      elsif @skill.scope == 3 or @skill.scope == 5
        # アクターの選択を開始
        start_actor_select
      # 効果範囲が単体ではない場合
      else
        # アクションを設定
        @active_actor.current_action.kind = 1
        # スキルの選択を終了
        end_skill_select
        # 次のアクターのコマンド入力へ
        phase3_next_actor
      end
      return
    end
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (アクターコマンドフェーズ : アイテム選択)
  #--------------------------------------------------------------------------
  def update_phase3_item_select
    # コマンド選択中に行動不能になった場合
    unless @active_actor.inputable?
      @active_actor.current_action.clear
      command_delete
      # 次のアクターのコマンド入力へ
      phase3_next_actor
      return
    end
    # アイテムウィンドウを可視状態にする
    @item_window.visible = true
    # アイテムウィンドウを更新
    @item_window.update
    # B ボタンが押された場合
    if Input.trigger?(Input::B)
      # キャンセル SE を演奏
      $game_system.se_play($data_system.cancel_se)
      # アイテムの選択を終了
      end_item_select
      return
    end
    # C ボタンが押された場合
    if Input.trigger?(Input::C)
      # アイテムウィンドウで現在選択されているデータを取得
      @item = @item_window.item
      # 使用できない場合
      unless $game_party.item_can_use?(@item.id)
        # ブザー SE を演奏
        $game_system.se_play($data_system.buzzer_se)
        return
      end
      # 決定 SE を演奏
      $game_system.se_play($data_system.decision_se)
      # アクションを設定
      @active_actor.current_action.item_id = @item.id
      # アイテムウィンドウを不可視状態にする
      @item_window.visible = false
      # 効果範囲が敵単体の場合
      if @item.scope == 1
        # エネミーの選択を開始
        start_enemy_select
      # 効果範囲が味方単体の場合
      elsif @item.scope == 3 or @item.scope == 5
        # アクターの選択を開始
        start_actor_select
      # 効果範囲が単体ではない場合
      else
        # アクションを設定
        @active_actor.current_action.kind = 2
        # アイテムの選択を終了
        end_item_select
        # 次のアクターのコマンド入力へ
        phase3_next_actor
      end
      return
    end
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (アクターコマンドフェーズ : エネミー選択)
  #--------------------------------------------------------------------------
  def update_phase3_enemy_select
    # コマンド選択中に行動不能になった場合
    unless @active_actor.inputable?
      # カメラを元に戻す
      if @camera == "select"
        @spriteset.screen_target(0, 0, 1)
      end
      @active_actor.current_action.clear
      command_delete
      # 次のアクターのコマンド入力へ
      phase3_next_actor
      return
    end
    # エネミーアローを更新
    @enemy_arrow.update
    # B ボタンが押された場合
    if Input.trigger?(Input::B)
      # キャンセル SE を演奏
      $game_system.se_play($data_system.cancel_se)
      # カメラを元に戻す
      if @camera == "select"
        # カメラの設定
        @camera = "command"
        plus = ($game_party.actors.size - 1) / 2.0 - @actor_index
        y = [(plus.abs - 1.5) * 10 , 0].min
        @spriteset.screen_target(plus * 50, y, 1.0 + y * 0.002)
      end
      # エネミーの選択を終了
      end_enemy_select
      return
    end
    # C ボタンが押された場合
    if Input.trigger?(Input::C)
      # 決定 SE を演奏
      $game_system.se_play($data_system.decision_se)
      # アクションを設定
      @active_actor.current_action.kind = 0
      @active_actor.current_action.basic = 0
      @active_actor.current_action.target_index = @enemy_arrow.index
      # スキルウィンドウ表示中の場合
      if @skill_window != nil
        # アクションを再設定
        @active_actor.current_action.kind = 1
        # スキルの選択を終了
        end_skill_select
      end
      # アイテムウィンドウ表示中の場合
      if @item_window != nil
        # アクションを再設定
        @active_actor.current_action.kind = 2
        # アイテムの選択を終了
        end_item_select
      end
      # エネミーの選択を終了
      end_enemy_select
      # 次のアクターのコマンド入力へ
      phase3_next_actor
    end
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (アクターコマンドフェーズ : アクター選択)
  #--------------------------------------------------------------------------
  def update_phase3_actor_select
    # コマンド選択中に行動不能になった場合
    unless @active_actor.inputable?
      @active_actor.current_action.clear
      command_delete
      # 次のアクターのコマンド入力へ
      phase3_next_actor
      return
    end
    # アクターアローを更新
    @actor_arrow.update
    # B ボタンが押された場合
    if Input.trigger?(Input::B)
      # キャンセル SE を演奏
      $game_system.se_play($data_system.cancel_se)
      # アクターの選択を終了
      end_actor_select
      return
    end
    # C ボタンが押された場合
    if Input.trigger?(Input::C)
      # 決定 SE を演奏
      $game_system.se_play($data_system.decision_se)
      # アクションを設定
      @active_actor.current_action.kind = 0
      @active_actor.current_action.basic = 0
      @active_actor.current_action.target_index = @actor_arrow.index
      # アクターの選択を終了
      end_actor_select
      # スキルウィンドウ表示中の場合
      if @skill_window != nil
        # アクションを再設定
        @active_actor.current_action.kind = 1
        # スキルの選択を終了
        end_skill_select
      end
      # アイテムウィンドウ表示中の場合
      if @item_window != nil
        # アクションを再設定
        @active_actor.current_action.kind = 2
        # アイテムの選択を終了
        end_item_select
      end
      # 次のアクターのコマンド入力へ
      phase3_next_actor
    end
  end
  #--------------------------------------------------------------------------
  # ● エネミー選択開始
  #--------------------------------------------------------------------------
  alias :start_enemy_select_rtab :start_enemy_select
  def start_enemy_select
    @camera = "select"
    for enemy in $game_troop.enemies
      if enemy.exist?
        zoom = 1 / enemy.zoom
        @spriteset.screen_target(enemy.attack_x(zoom) * 0.75,
                                  enemy.attack_y(zoom) * 0.75, zoom)
        break
      end
    end
    # オリジナルの処理
    start_enemy_select_rtab
  end
  #--------------------------------------------------------------------------
  # ● エネミー選択終了
  #--------------------------------------------------------------------------
  alias :end_enemy_select_rtab :end_enemy_select
  def end_enemy_select
    # オリジナルの処理
    end_enemy_select_rtab
    if (@action == 0 and not @action_battlers.empty?) or
          (@camera == "select" and (@active_actor.current_action.kind != 0 or
                                            @active_actor.animation1_id != 0))
      @spriteset.screen_target(0, 0, 1)
    end
  end
  #--------------------------------------------------------------------------
  # ● スキル選択開始
  #--------------------------------------------------------------------------
  def start_skill_select
    # スキルウィンドウを作成
    @skill_window = Window_Skill.new(@active_actor)
    # ヘルプウィンドウを関連付け
    @skill_window.help_window = @help_window
    # アクターコマンドウィンドウを無効化
    @actor_command_window.active = false
    @actor_command_window.visible = false
  end

#==============================================================================
# ■ Scene_Battle (分割定義 4)
#------------------------------------------------------------------------------
# 　バトル画面の処理を行うクラスです。
#==============================================================================

  #--------------------------------------------------------------------------
  # ● メインフェーズ開始
  #--------------------------------------------------------------------------
  def start_phase4
    $game_temp.battle_main_phase = true
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (メインフェーズ)
  #--------------------------------------------------------------------------
  def update_phase4
    # アクションを強制されているバトラーが存在する場合
    if $game_temp.forcing_battler != nil
      battler = $game_temp.forcing_battler
      if battler.current_action.forcing == false
        if @action_battlers.include?(battler)
          if @action > 0 or @action_battlers[0].phase == 1
            @action_battlers.delete(battler)
            @action_battlers.push(battler)
          end
          if battler.phase == 1 
            battler.current_action.forcing = true
            force_action(battler)
          end
        else
          battler.current_action.forcing = true
          force_action(battler)
          action_start(battler)
          @action_battlers.delete(battler)
          @action_battlers.push(battler)
        end
        battler.at = @max
        battler.atp = 100 * battler.at / @max
      end
    end
    # action が1以上の場合、一斉に行動を起こす
    for battler in @action_battlers.reverse
      # ウェイト中の場合
      if battler.wait > 0
        # ウェイトカウントを減らす
        battler.wait -= 1
        break if @action == 0
        next
      end
      unless fin? and battler.phase < 3 and
          not $game_system.battle_interpreter.running?
        action_phase(battler)
      end
      break if @action == 0
    end
    # アクションを強制されているバトラーが存在しない場合
    if $game_temp.forcing_battler == nil
      # バトルイベントをセットアップ
      setup_battle_event
      # バトルイベント実行中の場合
      if $game_system.battle_interpreter.running?
        return
      end
    end
    # 勝敗を決した際の処理
    if fin?
      # 敗北時、指定時間ウェイト
      if $game_party.all_dead? and @after_wait[0] > 0
        @after_wait[0] -= 1
        return
      end
      # 勝利時、指定時間ウェイト
      if victory? and @after_wait[1] > 0
        @after_wait[1] -= 1
        return
      end
      # 戦闘が終了し、かつアクターが行動直前の場合はアクターの行動を消去
      for battler in @action_battlers.reverse
        if battler.phase < 3 and not $game_system.battle_interpreter.running?
          @action_battlers.delete(battler)
        end
      end
      # 勝敗判定
      if @action_battlers.empty? and
          not $game_system.battle_interpreter.running?
        judge
      end
    end
  end
  #--------------------------------------------------------------------------
  # ● アクション更新 (メインフェーズ)
  #--------------------------------------------------------------------------
  def action_phase(battler)
    # action が 1 の場合、バトラーが行動中かどうか確認
    if @action == 1 and battler.phase <= 3
      for target in battler.target
        speller = synthe?(target)
        if speller == nil
          # ターゲットが通常行動中の場合
          if @action_battlers.include?(target)
            if target.phase > 2
              return
            end
          end
        else
          # ターゲットが連携スキル発動中の場合
          for spell in speller
            if @action_battlers.include?(spell)
              if spell.phase > 2
                return
              end
            end
          end
        end
      end
    end
    case battler.phase
    when 1
      update_phase4_step1(battler)
    when 2
      update_phase4_step2(battler)
    when 3
      update_phase4_step3(battler)
    when 4
      update_phase4_step4(battler)
    when 5
      update_phase4_step5(battler)
    when 6
      update_phase4_step6(battler)
    end
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (メインフェーズ ステップ 1 : アクション準備)
  #--------------------------------------------------------------------------
  def update_phase4_step1(battler)
    # すでに戦闘から外されている場合
    if battler.index == nil
      @action_battlers.delete(battler)
      anime_wait_return
      return
    end
    speller = synthe?(battler)
    if speller == nil
      # ダメージ食らい中の場合
      unless battler.damage.empty? or @action > 2
        return
      end
      # 行動可能かどうか判定
      unless battler.movable?
        battler.phase = 6
        return
      end
    else
      # ダメージ食らい中の場合
      for spell in speller
        unless spell.damage.empty? or @action > 2
          return
        end
        # 行動可能かどうか判定
        unless spell.movable?
          battler.phase = 6
          return
        end
      end
    end
    # スキル使用時、詠唱時間設定
    # 強制アクションかつ @force が 2 の時はスキルを即時発動
    if battler.current_action.kind == 1 and
      (not battler.current_action.forcing or @force != 2)
      if battler.rtp == 0
        # スキル詠唱中ならば、解除
        skill_reset(battler)
        # スキル詠唱時間設定
        recite_time(battler)
        # 連携技設定
        synthe_spell(battler)
        # スキルを詠唱する場合
        if battler.rtp > 0
          # 強制アクションかつ @force が 1 の時は連携スキルのみ即時発動
          speller = synthe?(battler)
          if battler.current_action.forcing and @force > 0 and speller != nil
            for spell in speller
              spell.rt = spell.rtp
            end
          else
            battler.blink = true
            if battler.current_action.forcing
              $game_temp.forcing_battler = nil
              battler.current_action.forcing = false
            end
            @action_battlers.delete(battler)
            return
          end
        end
      end
    end
    # アクターの明滅エフェクト OFF
    if battler != nil
      battler.blink = false
    end
    speller = synthe?(battler)
    if speller == nil
      @spell_p.delete(battler)
      @spell_e.delete(battler)
    else
      for spell in speller
        spell.blink = false
        @spell_p.delete(spell)
        @spell_e.delete(spell)
      end
    end
    # ステップ 2 に移行
    battler.phase = 2
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (メインフェーズ ステップ 2 : アクション開始)
  #--------------------------------------------------------------------------
  def update_phase4_step2(battler)
    # 強制アクションでなければ
    unless battler.current_action.forcing
      # 制約が [敵を通常攻撃する] か [味方を通常攻撃する] の場合
      if battler.restriction == 2 or battler.restriction == 3
        # アクションに攻撃を設定
        battler.current_action.kind = 0
        battler.current_action.basic = 0
      end
    end
    # アクションの種別で分岐
    case battler.current_action.kind
    when 0  # 基本
      if fin?
        battler.phase = 6
        return
      end
      make_basic_action_result(battler)
    when 1  # スキル
      if fin? and $data_skills[battler.current_action.skill_id].scope == 1..2
        battler.phase = 6
        return
      end
      make_skill_action_result(battler)
    when 2  # アイテム
      if fin? and $data_items[battler.current_action.item_id].scope == 1..2
        battler.phase = 6
        return
      end
      make_item_action_result(battler)
    end
    if battler.phase == 2
      # ステップ 3 に移行
      battler.phase = 3
    end
  end
  #--------------------------------------------------------------------------
  # ● 基本アクション 結果作成
  #--------------------------------------------------------------------------
  def make_basic_action_result(battler)
    # 攻撃の場合
    if battler.current_action.basic == 0
      # アニメーション ID を設定
      battler.anime1 = battler.animation1_id
      battler.anime2 = battler.animation2_id
      # 行動側バトラーがエネミーの場合
      if battler.is_a?(Game_Enemy)
        if battler.restriction == 3
          target = $game_troop.random_target_enemy
        elsif battler.restriction == 2
          target = $game_party.random_target_actor
        else
          index = battler.current_action.target_index
          target = $game_party.smooth_target_actor(index)
        end
      end
      # 行動側バトラーがアクターの場合
      if battler.is_a?(Game_Actor)
        if battler.restriction == 3
          target = $game_party.random_target_actor
        elsif battler.restriction == 2
          target = $game_troop.random_target_enemy
        else
          index = battler.current_action.target_index
          target = $game_troop.smooth_target_enemy(index)
        end
      end
      # 対象側バトラーの配列を設定
      battler.target = [target]
      # 通常攻撃の効果を適用
      for target in battler.target
        target.attack_effect(battler)
      end
      return
    end
    # 防御の場合
    if battler.current_action.basic == 1
      return
    end
    # 逃げるの場合
    if battler.is_a?(Game_Enemy) and battler.current_action.basic == 2
      return
    end
    # 何もしないの場合
    if battler.current_action.basic == 3
      # ステップ 6 に移行
      battler.phase = 6
      return
    end
  end
  #--------------------------------------------------------------------------
  # ● スキルまたはアイテムの対象側バトラー設定
  #     scope : スキルまたはアイテムの効果範囲
  #--------------------------------------------------------------------------
  def set_target_battlers(scope, battler)
    # 行動側バトラーがエネミーの場合
    if battler.is_a?(Game_Enemy)
      # 効果範囲で分岐
      case scope
      when 1  # 敵単体
        index =battler.current_action.target_index
        battler.target.push($game_party.smooth_target_actor(index))
      when 2  # 敵全体
        for actor in $game_party.actors
          if actor.exist?
            battler.target.push(actor)
          end
        end
      when 3  # 味方単体
        index = battler.current_action.target_index
        battler.target.push($game_troop.smooth_target_enemy(index))
      when 4  # 味方全体
        for enemy in $game_troop.enemies
          if enemy.exist?
            battler.target.push(enemy)
          end
        end
      when 5  # 味方単体 (HP 0) 
        index = battler.current_action.target_index
        enemy = $game_troop.enemies[index]
        if enemy != nil and enemy.hp0?
          battler.target.push(enemy)
        end
      when 6  # 味方全体 (HP 0) 
        for enemy in $game_troop.enemies
          if enemy != nil and enemy.hp0?
            battler.target.push(enemy)
          end
        end
      when 7  # 使用者
        battler.target.push(battler)
      end
    end
    # 行動側バトラーがアクターの場合
    if battler.is_a?(Game_Actor)
      # 効果範囲で分岐
      case scope
      when 1  # 敵単体
        index = battler.current_action.target_index
        battler.target.push($game_troop.smooth_target_enemy(index))
      when 2  # 敵全体
        for enemy in $game_troop.enemies
          if enemy.exist?
            battler.target.push(enemy)
          end
        end
      when 3  # 味方単体
        index = battler.current_action.target_index
        battler.target.push($game_party.smooth_target_actor(index))
      when 4  # 味方全体
        for actor in $game_party.actors
          if actor.exist?
            battler.target.push(actor)
          end
        end
      when 5  # 味方単体 (HP 0) 
        index = battler.current_action.target_index
        actor = $game_party.actors[index]
        if actor != nil and actor.hp0?
          battler.target.push(actor)
        end
      when 6  # 味方全体 (HP 0) 
        for actor in $game_party.actors
          if actor != nil and actor.hp0?
            battler.target.push(actor)
          end
        end
      when 7  # 使用者
        battler.target.push(battler)
      end
    end
  end
  #--------------------------------------------------------------------------
  # ● スキルアクション 結果作成
  #--------------------------------------------------------------------------
  def make_skill_action_result(battler)
    # スキルを取得
    @skill = $data_skills[battler.current_action.skill_id]
    # 連携スキルであるかどうか確認
    speller = synthe?(battler)
    # 強制アクションでなければ
    unless battler.current_action.forcing
      # SP 切れなどで使用できなくなった場合
      if speller == nil
        unless battler.skill_can_use?(@skill.id)
          # ステップ 6 に移行
          battler.phase = 6
         return
        end
      end
    end
    # SP 消費
    temp = false
    if speller != nil
      for spell in speller
        if spell.current_action.spell_id == 0
          spell.sp -= @skill.sp_cost
        else
          spell.sp -= $data_skills[spell.current_action.spell_id].sp_cost
        end
        # ステータスウィンドウをリフレッシュ
        status_refresh(spell)
      end
    else
      battler.sp -= @skill.sp_cost
      # ステータスウィンドウをリフレッシュ
      status_refresh(battler)
    end
    # アニメーション ID を設定
    battler.anime1 = @skill.animation1_id
    battler.anime2 = @skill.animation2_id
    # コモンイベント ID を設定
    battler.event = @skill.common_event_id
    # 対象側バトラーを設定
    set_target_battlers(@skill.scope, battler)
    # スキルの効果を適用
    for target in battler.target
      if speller != nil
        damage = 0
        d_result = false
        effective = false
        state_p = []
        state_m = []
        for spell in speller
          if spell.current_action.spell_id != 0
            @skill = $data_skills[spell.current_action.spell_id]
          end
          effective |= target.skill_effect(spell, @skill)
          if target.damage[spell].class != String
            d_result = true
            damage += target.damage[spell]
          elsif effective
            effect = target.damage[spell]
          end
          state_p += target.state_p[spell]
          state_m += target.state_m[spell]
          target.damage.delete(spell)
          target.state_p.delete(spell)
          target.state_m.delete(spell)
        end
        if d_result
          target.damage[battler] = damage
        elsif effective
          target.damage[battler] = effect
        else
          target.damage[battler] = 0
        end
        target.state_p[battler] = state_p
        target.state_m[battler] = state_m
      else
        target.skill_effect(battler, @skill)
      end
    end
  end
  #--------------------------------------------------------------------------
  # ● アイテムアクション 結果作成
  #--------------------------------------------------------------------------
  def make_item_action_result(battler)
    # アイテムを取得
    @item = $data_items[battler.current_action.item_id]
    # アイテム切れなどで使用できなくなった場合
    unless $game_party.item_can_use?(@item.id)
      # ステップ 6 に移行
      battler.phase = 6
      return
    end
    # 消耗品の場合
    if @item.consumable
      # 使用したアイテムを 1 減らす
      $game_party.lose_item(@item.id, 1)
    end
    # アニメーション ID を設定
    battler.anime1 = @item.animation1_id
    battler.anime2 = @item.animation2_id
    # コモンイベント ID を設定
    battler.event = @item.common_event_id
    # 対象を決定
    index = battler.current_action.target_index
    target = $game_party.smooth_target_actor(index)
    # 対象側バトラーを設定
    set_target_battlers(@item.scope, battler)
    # アイテムの効果を適用
    for target in battler.target
      target.item_effect(@item, battler)
    end
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (メインフェーズ ステップ 3 : 行動側アニメーション)
  #--------------------------------------------------------------------------
  def update_phase4_step3(battler)
    # ヘルプウィンドウの更新。アクションの種別で分岐
    case battler.current_action.kind
    when 0  # 基本
      if battler.current_action.basic == 1
        @help_window.set_text($data_system.words.guard, 1)
        @help_wait = @help_time
      end
      if battler.current_action.basic == 2
        # 逃げる
        @help_window.set_text("逃げる", 1)
        @help_wait = @help_time
        battler.escape
        battler.phase = 4
        return
      end
    when 1  # スキル
      skill =  $data_skills[battler.current_action.skill_id]
      @help_window.set_text(skill.name, 1)
      @help_wait = @help_time
    when 2  # アイテム
      item = $data_items[battler.current_action.item_id]
      @help_window.set_text(item.name, 1)
      @help_wait = @help_time
    end
    # 行動側アニメーション (ID が 0 の場合は白フラッシュ)
    if battler.anime1 == 0
      battler.white_flash = true
      battler.wait = 5
      # カメラ設定
      if battler.target[0].is_a?(Game_Enemy)
        camera_set(battler)
      end
    else
      battler.animation.push([battler.anime1, true])
      speller = synthe?(battler)
      if speller != nil
        for spell in speller
          if spell != battler
            if spell.current_action.spell_id == 0
              spell.animation.push([battler.anime1, true])
            else
              skill = spell.current_action.spell_id
              spell.animation.push([$data_skills[skill].animation1_id, true])
              spell.current_action.spell_id = 0
            end
          end
        end
      end
      battler.wait = 2 * $data_animations[battler.anime1].frame_max - 10
    end
    # ステップ 4 に移行
    battler.phase = 4
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (メインフェーズ ステップ 4 : 対象側アニメーション)
  #--------------------------------------------------------------------------
  def update_phase4_step4(battler)
    # カメラ設定
    if battler.target[0].is_a?(Game_Enemy) and battler.anime1 != 0
       camera_set(battler)
    end
    # 対象側アニメーション
    for target in battler.target
      target.animation.push([battler.anime2,
                                          (target.damage[battler] != "Miss")])
      unless battler.anime2 == 0
        battler.wait = 2 * $data_animations[battler.anime2].frame_max - 10
      end
    end
    # ステップ 5 に移行
    battler.phase = 5
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (メインフェーズ ステップ 5 : ダメージ表示)
  #--------------------------------------------------------------------------
  def update_phase4_step5(battler)
    # ダメージ表示
    for target in battler.target
      if target.damage[battler] != nil
        target.damage_pop[battler] = true
        target.damage_effect(battler, battler.current_action.kind)
        battler.wait = @damage_wait
        # ステータスウィンドウをリフレッシュ
        status_refresh(target)
      end
    end
    # ステップ 6 に移行
    battler.phase = 6
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新 (メインフェーズ ステップ 6 : リフレッシュ)
  #--------------------------------------------------------------------------
  def update_phase4_step6(battler)
    # カメラを戻す
    if battler.target[0].is_a?(Game_Enemy) and @camera == battler
      @spriteset.screen_target(0, 0, 1)
    end
    # スキルラーニング
    if battler.target[0].is_a?(Game_Actor) and battler.current_action.kind == 1
      for target in battler.target
        skill_learning(target, target.class_id,
                        battler.current_action.skill_id)
      end
    end
    # アクション強制対象のバトラーをクリア
    if battler.current_action.forcing == true and
        battler.current_action.force_kind == 0 and
        battler.current_action.force_basic == 0 and
        battler.current_action.force_skill_id == 0
      $game_temp.forcing_battler = nil
      battler.current_action.forcing = false
    end
    refresh_phase(battler)
    speller = synthe?(battler)
    if speller != nil
      for spell in speller
        if spell != battler
          refresh_phase(spell)
        end
      end
      synthe_delete(speller)
    end
    # コモンイベント ID が有効の場合
    if battler.event > 0
      # イベントをセットアップ
      common_event = $data_common_events[battler.event]
      $game_system.battle_interpreter.setup(common_event.list, 0)
    end
    act = 0
    for actor in $game_party.actors + $game_troop.enemies
      if actor.movable?
        act += 1
      end
    end
    if @turn_cnt >= act and act > 0
      @turn_cnt %= act
      $game_temp.battle_turn += 1
      # バトルイベントの全ページを検索
      for index in 0...$data_troops[@troop_id].pages.size
        # イベントページを取得
        page = $data_troops[@troop_id].pages[index]
        # このページのスパンが [ターン] の場合
        if page.span == 1
          # 実行済みフラグをクリア
          $game_temp.battle_event_flags[index] = false
        end
      end
    end
    battler.phase = 1
    @action_battlers.delete(battler)
  end
  #--------------------------------------------------------------------------
  # ● リフレッシュ
  #--------------------------------------------------------------------------
  def refresh_phase(battler)
    battler.at -= @max
    if battler.movable?
      battler.atp = 100 * battler.at / @max
    end
    spell_reset(battler)
    # スリップダメージ
    if battler.hp > 0 and battler.slip_damage?
      battler.slip_damage_effect
      battler.damage_pop["slip"] = true
    end
    # ステート自然解除
    battler.remove_states_auto
    # ステータスウィンドウをリフレッシュ
    status_refresh(battler, true)
    unless battler.movable?
      return
    end
    # ターン数カウント
    @turn_cnt += 1
  end
  #--------------------------------------------------------------------------
  # ● バトラーアクションスタート
  #--------------------------------------------------------------------------
  def action_start(battler)
    battler.phase = 1
    battler.anime1 = 0
    battler.anime2 = 0
    battler.target = []
    battler.event = 0
    @action_battlers.unshift(battler)
  end
  #--------------------------------------------------------------------------
  # ● ステータスウィンドウをリフレッシュ
  #--------------------------------------------------------------------------
  def status_refresh(battler, at = false)
    if battler.is_a?(Game_Actor)
      for i in 0...$game_party.actors.size
        if battler == $game_party.actors[i]
          number = i + 1
        end
      end
      @status_window.refresh(number)
      if at == true
        @status_window.at_refresh(number)
      end
    end
  end
  #--------------------------------------------------------------------------
  # ● アニメウェイト判断処理
  #--------------------------------------------------------------------------
  def anime_wait_return
    if (@action_battlers.empty? or @anime_wait == false) and
        not $game_system.battle_interpreter.running?
      # エネミーアローが有効の場合
      if @enemy_arrow != nil
        return [@active - 2, 0].min == 0
      # アクターアローが有効の場合
      elsif @actor_arrow != nil
        return [@active - 2, 0].min == 0
      # スキルウィンドウが有効の場合
      elsif @skill_window != nil
        return [@active - 3, 0].min == 0
      # アイテムウィンドウが有効の場合
      elsif @item_window != nil
        return [@active - 3, 0].min == 0
      # アクターコマンドウィンドウが有効の場合
      elsif @actor_command_window.active
        return [@active - 1, 0].min == 0
      else
        return true
      end
    else
      return false
    end
  end
  #--------------------------------------------------------------------------
  # ● アクターコマンド消去判断
  #--------------------------------------------------------------------------
  def command_delete
    # エネミーアローが有効の場合
    if @enemy_arrow != nil
      end_enemy_select
    # アクターアローが有効の場合
    elsif @actor_arrow != nil
      end_actor_select
    end
    # スキルウィンドウが有効の場合
    if @skill_window != nil
      end_skill_select
    # アイテムウィンドウが有効の場合
    elsif @item_window != nil
      end_item_select
    end
    # アクターコマンドウィンドウが有効の場合
    if @actor_command_window.active
      @command.shift
      @command_a = false
      # メインフェーズフラグをセット
      $game_temp.battle_main_phase = true
      # アクターコマンドウィンドウを無効化
      @actor_command_window.active = false
      @actor_command_window.visible = false
      # アクターの明滅エフェクト OFF
      if @active_actor != nil
        @active_actor.blink = false
      end
    end
  end
  #--------------------------------------------------------------------------
  # ● 強制アクション設定
  #--------------------------------------------------------------------------
  def force_action(battler)
    battler.current_action.kind = battler.current_action.force_kind
    battler.current_action.basic = battler.current_action.force_basic
    battler.current_action.skill_id = battler.current_action.force_skill_id
    battler.current_action.force_kind = 0
    battler.current_action.force_basic = 0
    battler.current_action.force_skill_id = 0
  end
  #--------------------------------------------------------------------------
  # ● カメラセット
  #--------------------------------------------------------------------------
  def camera_set(battler)
    @camera = battler
    if battler.target.size == 1
      if battler.current_action.kind == 0
        zoom = 1.2 / battler.target[0].zoom
      elsif synthe?(battler) == nil
        zoom = 1.5 / battler.target[0].zoom
      else
        zoom = 2.0 / battler.target[0].zoom
      end
      @spriteset.screen_target(battler.target[0].attack_x(zoom),
                                battler.target[0].attack_y(zoom), zoom)
    else
      @spriteset.screen_target(0, 0, 0.75)
    end
  end
  #--------------------------------------------------------------------------
  # ● スキル詠唱タイム作成
  #--------------------------------------------------------------------------
  def recite_time(battler)
  end
  #--------------------------------------------------------------------------
  # ● 連携スキル判別
  #--------------------------------------------------------------------------
  def synthe_spell(battler)
  end
  #--------------------------------------------------------------------------
  # ● スキルラーニングシステム
  #--------------------------------------------------------------------------
  def skill_learning(actor, class_id, skill_id)
  end
  #--------------------------------------------------------------------------
  # ● 行動可能判定
  #--------------------------------------------------------------------------
  def active?(battler)
    speller = synthe?(battler)
    if speller != nil
      if synthe_delete?(speller)
        return false
      end
    else
      unless battler.inputable?
        spell_reset(battler)
        unless battler.movable?
          battler.atp = 0
          return false
        end
      end
      if battler.current_action.forcing
        spell_reset(battler)
      end
    end
    return true
  end
  #--------------------------------------------------------------------------
  # ● 合成スキル詠唱中か？
  #--------------------------------------------------------------------------
  def synthe?(battler)
    for speller in @synthe
      if speller.include?(battler)
        return speller
      end
    end
    return nil
  end
  #--------------------------------------------------------------------------
  # ● 合成スキル消去判断
  #--------------------------------------------------------------------------
  def synthe_delete?(speller)
    for battler in speller
      if not battler.inputable? and dead_ok?(battler)
        synthe_delete(speller)
        return true
      end
    end
    return false
  end
  #--------------------------------------------------------------------------
  # ● 合成スキル消去
  #--------------------------------------------------------------------------
  def synthe_delete(speller)
    for battler in speller
      spell_reset(battler)
      if dead_ok?(battler)
        @action_battlers.delete(battler)
      end
    end
    @synthe.delete(speller)
  end
  #--------------------------------------------------------------------------
  # ● 連携含むスキル詠唱解除
  #--------------------------------------------------------------------------
  def skill_reset(battler)
    speller = synthe?(battler)
    if speller != nil
      synthe_delete(speller)
    else
      spell_reset(battler)
    end
  end
  #--------------------------------------------------------------------------
  # ● スキル詠唱解除
  #--------------------------------------------------------------------------
  def spell_reset(battler)
    battler.rt = 0
    battler.rtp = 0
    battler.blink = false
    battler.spell = false
    battler.current_action.spell_id = 0
    @spell_p.delete(battler)
    @spell_e.delete(battler)
  end
  #--------------------------------------------------------------------------
  # ● 戦闘終了判定
  #--------------------------------------------------------------------------
  def fin?
   return (victory? or $game_party.all_dead? or $game_party.actors.size == 0)
  end
  #--------------------------------------------------------------------------
  # ● 敵全滅判定
  #--------------------------------------------------------------------------
  def victory?
    for battler in $game_troop.enemies
      if not battler.hidden and (battler.rest_hp > 0 or
          battler.immortal or battler.damage_pop.size > 0)
        return false
      end
    end
    return true
  end
  #--------------------------------------------------------------------------
  # ● 死亡許可判定
  #--------------------------------------------------------------------------
  def dead_ok?(battler)
    speller = synthe?(battler)
    if speller == nil
      if @action_battlers.include?(battler)
        if battler.phase > 2
          return false
        end
      end
    else
      for battler in speller
        if @action_battlers.include?(battler)
          if battler.phase > 2
            return false
          end
        end
      end
    end
    return true
  end
end

#==============================================================================
# ■ Game_Actor
#------------------------------------------------------------------------------
# 　アクターを扱うクラスです。このクラスは Game_Actors クラス ($game_actors)
# の内部で使用され、Game_Party クラス ($game_party) からも参照されます。
#==============================================================================

class Game_Actor < Game_Battler
  #--------------------------------------------------------------------------
  # ● バトル画面 X 座標の取得
  #--------------------------------------------------------------------------
  def screen_x
    # パーティ内の並び順から X 座標を計算して返す
    if self.index != nil
      return self.index * 160 + (4 - $game_party.actors.size) * 80 + 80
    else
      return 0
    end
  end
end

#==============================================================================
# ■ Spriteset_Battle
#------------------------------------------------------------------------------
# 　バトル画面のスプライトをまとめたクラスです。このクラスは Scene_Battle クラ
# スの内部で使用されます。
#==============================================================================

class Spriteset_Battle
  #--------------------------------------------------------------------------
  # ● 公開インスタンス変数
  #--------------------------------------------------------------------------
  attr_reader   :real_x                   # x座標補正（現在値）
  attr_reader   :real_y                   # y座標補正（現在値）
  attr_reader   :real_zoom                # 拡大率（現在値）
  #--------------------------------------------------------------------------
  # ● オブジェクト初期化
  #--------------------------------------------------------------------------
  def initialize
    # ビューポートを作成
    @viewport1 = Viewport.new(0, 0, 640, 480)
    @viewport2 = Viewport.new(0, 0, 640, 480)
    @viewport3 = Viewport.new(0, 0, 640, 480)
    @viewport4 = Viewport.new(0, 0, 640, 480)
    @viewport2.z = 101
    @viewport3.z = 200
    @viewport4.z = 5000
    @wait = 0
    @real_x = 0
    @real_y = 0
    @real_zoom = 1.0
    @target_x = 0
    @target_y = 0
    @target_zoom = 1.0
    @gap_x = 0
    @gap_y = 0
    @gap_zoom = 0.0
    # バトルバックスプライトを作成
    @battleback_sprite = Sprite.new(@viewport1)
    # エネミースプライトを作成
    @enemy_sprites = []
    for enemy in $game_troop.enemies.reverse
      @enemy_sprites.push(Sprite_Battler.new(@viewport1, enemy))
    end
    # アクタースプライトを作成
    @actor_sprites = []
    @actor_sprites.push(Sprite_Battler.new(@viewport2))
    @actor_sprites.push(Sprite_Battler.new(@viewport2))
    @actor_sprites.push(Sprite_Battler.new(@viewport2))
    @actor_sprites.push(Sprite_Battler.new(@viewport2))
    # 天候を作成
    @weather = RPG::Weather.new(@viewport1)
    # ピクチャスプライトを作成
    @picture_sprites = []
    for i in 51..100
      @picture_sprites.push(Sprite_Picture.new(@viewport3,
        $game_screen.pictures[i]))
    end
    # タイマースプライトを作成
    @timer_sprite = Sprite_Timer.new
    # フレーム更新
    update
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新
  #--------------------------------------------------------------------------
  def update
    # アクタースプライトの内容を更新 (アクターの入れ替えに対応)
    @actor_sprites[0].battler = $game_party.actors[0]
    @actor_sprites[1].battler = $game_party.actors[1]
    @actor_sprites[2].battler = $game_party.actors[2]
    @actor_sprites[3].battler = $game_party.actors[3]
    # バトルバックのファイル名が現在のものと違う場合
    if @battleback_name != $game_temp.battleback_name
      make_battleback
    end
    # 画面のスクロール
    screen_scroll
    # モンスターの位置補正
    for enemy in $game_troop.enemies
      enemy.real_x = @real_x
      enemy.real_y = @real_y
      enemy.real_zoom = @real_zoom
    end
    # バトラースプライトを更新
    for sprite in @enemy_sprites + @actor_sprites
      sprite.update
    end
    # 天候グラフィックを更新
    @weather.type = $game_screen.weather_type
    @weather.max = $game_screen.weather_max
    @weather.update
    # ピクチャスプライトを更新
    for sprite in @picture_sprites
      sprite.update
    end
    # タイマースプライトを更新
    @timer_sprite.update
    # 画面の色調とシェイク位置を設定
    @viewport1.tone = $game_screen.tone
    @viewport1.ox = $game_screen.shake
    # 画面のフラッシュ色を設定
    @viewport4.color = $game_screen.flash_color
    # ビューポートを更新
    @viewport1.update
    @viewport2.update
    @viewport4.update
  end
  #--------------------------------------------------------------------------
  # ● バトル背景の設定
  #--------------------------------------------------------------------------
  def make_battleback
    @battleback_name = $game_temp.battleback_name
    if @battleback_sprite.bitmap != nil
      @battleback_sprite.bitmap.dispose
    end
    @battleback_sprite.bitmap = RPG::Cache.battleback(@battleback_name)
    if @battleback_sprite.bitmap.width == 640 and
       @battleback_sprite.bitmap.height == 320
      @battleback_sprite.src_rect.set(0, 0, 1280, 640)
      @base_zoom = 2.0
      @battleback_sprite.zoom_x = @base_zoom
      @battleback_sprite.zoom_y = @base_zoom
      @real_y = 4
      @battleback_sprite.x = 320
      @battleback_sprite.y = @real_y
      @battleback_sprite.ox = @battleback_sprite.bitmap.width / 2
      @battleback_sprite.oy = @battleback_sprite.bitmap.height / 4
    elsif @battleback_sprite.bitmap.width == 640 and
          @battleback_sprite.bitmap.height == 480
      @battleback_sprite.src_rect.set(0, 0, 960, 720)
      @base_zoom = 1.5
      @battleback_sprite.zoom_x = @base_zoom
      @battleback_sprite.zoom_y = @base_zoom
      @battleback_sprite.x = 320
      @battleback_sprite.y = 0
      @battleback_sprite.ox = @battleback_sprite.bitmap.width / 2
      @battleback_sprite.oy = @battleback_sprite.bitmap.height / 4
    else
      @battleback_sprite.src_rect.set(0, 0, @battleback_sprite.bitmap.width,
                                      @battleback_sprite.bitmap.height)
      @base_zoom = 1.0
      @battleback_sprite.zoom_x = @base_zoom
      @battleback_sprite.zoom_y = @base_zoom
      @battleback_sprite.x = 320
      @battleback_sprite.y = 0
      @battleback_sprite.ox = @battleback_sprite.bitmap.width / 2
      @battleback_sprite.oy = @battleback_sprite.bitmap.height / 4
    end
  end
  #--------------------------------------------------------------------------
  # ● 画面のスクロール目標の位置・拡大率設定
  #--------------------------------------------------------------------------
  def screen_target(x, y, zoom)
    return unless $scene.drive
    @wait = $scene.scroll_time
    @target_x = x
    @target_y = y
    @target_zoom = zoom
    screen_over
    @gap_x = @target_x - @real_x
    @gap_y = @target_y - @real_y
    @gap_zoom = @target_zoom - @real_zoom
  end
  #--------------------------------------------------------------------------
  # ● 画面のスクロール
  #--------------------------------------------------------------------------
  def screen_scroll
    if @wait > 0
      @real_x = @target_x - @gap_x * (@wait ** 2) / ($scene.scroll_time ** 2)
      @real_y = @target_y - @gap_y * (@wait ** 2) / ($scene.scroll_time ** 2)
      @real_zoom = @target_zoom -
                    @gap_zoom * (@wait ** 2) / ($scene.scroll_time ** 2)
      @battleback_sprite.x = 320 + @real_x
      @battleback_sprite.y = @real_y
      @battleback_sprite.zoom_x = @base_zoom * @real_zoom
      @battleback_sprite.zoom_y = @base_zoom * @real_zoom
      @battleback_sprite.ox = @battleback_sprite.bitmap.width / 2
      @battleback_sprite.oy = @battleback_sprite.bitmap.height / 4
      @wait -= 1
    end
  end
  #--------------------------------------------------------------------------
  # ● スクリーンが画面外に出た時の補正処理
  #--------------------------------------------------------------------------
  def screen_over
    width = @battleback_sprite.bitmap.width * @base_zoom * @target_zoom / 2
    unless 324 + @target_x > width and 324 - @target_x > width
      if 324 + @target_x > width
        @target_x = width - 324
      elsif 324 - @target_x > width
        @target_x = 324 - width
      end
    end
    height = @battleback_sprite.bitmap.height * @base_zoom * @target_zoom / 4
    unless @target_y > height - 4 and 484 - @target_y > 3 * height
      if @target_y > height - 4
        @target_y = height - 4
      elsif 484 - @target_y > 3 * height
        @target_y = 484 - 3 * height
      end
    end
  end
end

#==============================================================================
# ■ Game_Battler (分割定義 1)
#------------------------------------------------------------------------------
# 　バトラーを扱うクラスです。このクラスは Game_Actor クラスと Game_Enemy クラ
# スのスーパークラスとして使用されます。
#==============================================================================

class Game_Battler
  #--------------------------------------------------------------------------
  # ● 公開インスタンス変数追加
  #--------------------------------------------------------------------------
  attr_accessor :up_level                  # レベルアップ数
  attr_accessor :at                        # AT（タイムゲージ）
  attr_accessor :atp                       # AT（表示用）
  attr_accessor :rt                        # RP（詠唱ゲージ）
  attr_accessor :rtp                       # RP（詠唱必要量）
  attr_accessor :spell                     # 合成スキル発動中
  attr_accessor :recover_hp                # HP回復量
  attr_accessor :recover_sp                # SP回復量
  attr_accessor :state_p                   # ステータス異常配列
  attr_accessor :state_m                   # ステータス異常配列
  attr_accessor :damage_sp                 # SPダメージ表示フラグ
  attr_accessor :animation                 # アニメーション ID, Hitの配列
  attr_accessor :phase
  attr_accessor :wait
  attr_accessor :target
  attr_accessor :anime1
  attr_accessor :anime2
  attr_accessor :event
  #--------------------------------------------------------------------------
  # ● オブジェクト初期化
  #--------------------------------------------------------------------------
  alias :initialize_rtab :initialize
  def initialize
    initialize_rtab
    @damage_pop = {}
    @damage = {}
    @damage_sp = {}
    @critical = {}
    @recover_hp = {}
    @recover_sp = {}
    @state_p = {}
    @state_m = {}
    @animation = []
    @phase = 1
    @wait = 0
    @target = []
    @anime1 = 0
    @anime2 = 0
    @event = 0
  end
  #--------------------------------------------------------------------------
  # ● 存在判定
  #--------------------------------------------------------------------------
  def exist?
    return (not @hidden and (@hp > 0 or @immortal or @damage.size > 0))
  end
  #--------------------------------------------------------------------------
  # ● 残HP予測
  #--------------------------------------------------------------------------
  def rest_hp
    # rest_hp に現HPを代入
    rest_hp = @hp
    # バトラーが受ける全ダメージをrest_hpに反映させる
    for pre_damage in @damage
      if pre_damage[1].is_a?(Numeric)
        rest_hp -= pre_damage[1]
      end
    end
    return rest_hp
  end
  #--------------------------------------------------------------------------
  # ● ステートの解除
  #     state_id : ステート ID
  #     force    : 強制解除フラグ (オートステートの処理で使用)
  #--------------------------------------------------------------------------
  def remove_state(state_id, force = false)
    # このステートが付加されている場合
    if state?(state_id)
      # 強制付加されたステートで、かつ解除が強制ではない場合
      if @states_turn[state_id] == -1 and not force
        # メソッド終了
        return
      end
      # 現在の HP が 0 かつ オプション [HP 0 の状態とみなす] が有効の場合
      if @hp == 0 and $data_states[state_id].zero_hp
        # ほかに [HP 0 の状態とみなす] ステートがあるかどうか判定
        zero_hp = false
        for i in @states
          if i != state_id and $data_states[i].zero_hp
            zero_hp = true
          end
        end
        # 戦闘不能を解除してよければ、HP を 1 に変更
        if zero_hp == false
          @hp = 1
        end
      end
      unless self.movable?
        # ステート ID を @states 配列および @states_turn ハッシュから削除
        @states.delete(state_id)
        @states_turn.delete(state_id)
        if self.movable?
          self.at = 0
        end
      else
        # ステート ID を @states 配列および @states_turn ハッシュから削除
        @states.delete(state_id)
        @states_turn.delete(state_id)
      end
    end
    # HP および SP の最大値チェック
    @hp = [@hp, self.maxhp].min
    @sp = [@sp, self.maxsp].min
  end
  #--------------------------------------------------------------------------
  # ● 通常攻撃の効果適用
  #     attacker : 攻撃者 (バトラー)
  #--------------------------------------------------------------------------
  def attack_effect(attacker)
    # クリティカルフラグをクリア
    self.critical[attacker] = false
    state_p[attacker] = []
    state_m[attacker] = []
    # 第一命中判定
    hit_result = (rand(100) < attacker.hit)
    # 命中の場合
    if hit_result == true
      # 基本ダメージを計算
      atk = [attacker.atk - self.pdef / 2, 0].max
      self.damage[attacker] = atk * (20 + attacker.str) / 20
      # 属性修正
      self.damage[attacker] *= elements_correct(attacker.element_set)
      self.damage[attacker] /= 100
      # ダメージの符号が正の場合
      if self.damage[attacker] > 0
        # クリティカル修正
        if rand(100) < 4 * attacker.dex / self.agi
          self.damage[attacker] *= 2
          self.critical[attacker] = true
        end
        # 防御修正
        if self.guarding?
          self.damage[attacker] /= 2
        end
      end
      # 分散
      if self.damage[attacker].abs > 0
        amp = [self.damage[attacker].abs * 15 / 100, 1].max
        self.damage[attacker] += rand(amp+1) + rand(amp+1) - amp
      end
      # 第二命中判定
      eva = 8 * self.agi / attacker.dex + self.eva
      hit = self.damage[attacker] < 0 ? 100 : 100 - eva
      hit = self.cant_evade? ? 100 : hit
      hit_result = (rand(100) < hit)
    end
    # 命中の場合
    if hit_result == true
      # ステート衝撃解除
      remove_states_shock
      # HP からダメージを減算
      # ステート変化
      @state_changed = false
      states_plus(attacker, attacker.plus_state_set)
      states_minus(attacker, attacker.minus_state_set)
    # ミスの場合
    else
      # ダメージに "Miss" を設定
      self.damage[attacker] = "Miss"
      # クリティカルフラグをクリア
      self.critical[attacker] = false
    end
    # メソッド終了
    return true
  end
  #--------------------------------------------------------------------------
  # ● スキルの効果適用
  #     user  : スキルの使用者 (バトラー)
  #     skill : スキル
  #--------------------------------------------------------------------------
  def skill_effect(user, skill)
    # クリティカルフラグをクリア
    self.critical[user] = false
    state_p[user] = []
    state_m[user] = []
    # スキルの効果範囲が HP 1 以上の味方で、自分の HP が 0、
    # またはスキルの効果範囲が HP 0 の味方で、自分の HP が 1 以上の場合
    if ((skill.scope == 3 or skill.scope == 4) and self.hp == 0) or
       ((skill.scope == 5 or skill.scope == 6) and self.hp >= 1)
      # メソッド終了
      return false
    end
    # 有効フラグをクリア
    effective = false
    # コモンイベント ID が有効の場合は有効フラグをセット
    effective |= skill.common_event_id > 0
    # 第一命中判定
    hit = skill.hit
    if skill.atk_f > 0
      hit *= user.hit / 100
    end
    hit_result = (rand(100) < hit)
    # 不確実なスキルの場合は有効フラグをセット
    effective |= hit < 100
    # 命中の場合
    if hit_result == true
      # 威力を計算
      power = skill.power + user.atk * skill.atk_f / 100
      if power > 0
        power -= self.pdef * skill.pdef_f / 200
        power -= self.mdef * skill.mdef_f / 200
        power = [power, 0].max
      end
      # 倍率を計算
      rate = 20
      rate += (user.str * skill.str_f / 100)
      rate += (user.dex * skill.dex_f / 100)
      rate += (user.agi * skill.agi_f / 100)
      rate += (user.int * skill.int_f / 100)
      # 基本ダメージを計算
      self.damage[user] = power * rate / 20
      # 属性修正
      self.damage[user] *= elements_correct(skill.element_set)
      self.damage[user] /= 100
      # ダメージの符号が正の場合
      if self.damage[user] > 0
        # 防御修正
        if self.guarding?
          self.damage[user] /= 2
        end
      end
      # 分散
      if skill.variance > 0 and self.damage[user].abs > 0
        amp = [self.damage[user].abs * skill.variance / 100, 1].max
        self.damage[user] += rand(amp+1) + rand(amp+1) - amp
      end
      # 第二命中判定
      eva = 8 * self.agi / user.dex + self.eva
      hit = self.damage[user] < 0 ? 100 : 100 - eva * skill.eva_f / 100
      hit = self.cant_evade? ? 100 : hit
      hit_result = (rand(100) < hit)
      # 不確実なスキルの場合は有効フラグをセット
      effective |= hit < 100
    end
    # 命中の場合
    if hit_result == true
      # 威力 0 以外の物理攻撃の場合
      if skill.power != 0 and skill.atk_f > 0
        # ステート衝撃解除
        remove_states_shock
        # 有効フラグをセット
        effective = true
      end
      # HP の変動判定
      last_hp = [[self.hp - self.damage[user], self.maxhp].min, 0].max
      # 効果判定
      effective |= self.hp != last_hp
      # ステート変化
      @state_changed = false
      effective |= states_plus(user, skill.plus_state_set)
      effective |= states_minus(user, skill.minus_state_set)
      unless $game_temp.in_battle
        self.damage_effect(user, 1)
      end
      # 威力が 0 の場合
      if skill.power == 0
        # ダメージに空文字列を設定
        self.damage[user] = ""
        # ステートに変化がない場合
        unless @state_changed
          # ダメージに "Miss" を設定
          self.damage[user] = "Miss"
        end
      end
    # ミスの場合
    else
      # ダメージに "Miss" を設定
      self.damage[user] = "Miss"
    end
    # 戦闘中でない場合
    unless $game_temp.in_battle
      # ダメージに nil を設定
      self.damage[user] = nil
    end
    # メソッド終了
    return effective
  end
  #--------------------------------------------------------------------------
  # ● アイテムの効果適用
  #     item : アイテム
  #--------------------------------------------------------------------------
  def item_effect(item, user = $game_party.actors[0])
    # クリティカルフラグをクリア
    self.critical[user] = false
    state_p[user] = []
    state_m[user] = []
    self.recover_hp[user] = 0
    self.recover_sp[user] = 0
    # アイテムの効果範囲が HP 1 以上の味方で、自分の HP が 0、
    # またはアイテムの効果範囲が HP 0 の味方で、自分の HP が 1 以上の場合
    if ((item.scope == 3 or item.scope == 4) and self.hp == 0) or
       ((item.scope == 5 or item.scope == 6) and self.hp >= 1)
      # メソッド終了
      return false
    end
    # 有効フラグをクリア
    effective = false
    # コモンイベント ID が有効の場合は有効フラグをセット
    effective |= item.common_event_id > 0
    # 命中判定
    hit_result = (rand(100) < item.hit)
    # 不確実なスキルの場合は有効フラグをセット
    effective |= item.hit < 100
    # 命中の場合
    if hit_result == true
      # 回復量を計算
      self.recover_hp[user] = maxhp * item.recover_hp_rate / 100 +
                              item.recover_hp
      self.recover_sp[user] = maxsp * item.recover_sp_rate / 100 +
                              item.recover_sp
      if self.recover_hp[user] < 0
        self.recover_hp[user] += self.pdef * item.pdef_f / 20
        self.recover_hp[user] += self.mdef * item.mdef_f / 20
        self.recover_hp[user] = [self.recover_hp[user], 0].min
      end
      # 属性修正
      self.recover_hp[user] *= elements_correct(item.element_set)
      self.recover_hp[user] /= 100
      self.recover_sp[user] *= elements_correct(item.element_set)
      self.recover_sp[user] /= 100
      # 分散
      if item.variance > 0 and self.recover_hp[user].abs > 0
        amp = [self.recover_hp[user].abs * item.variance / 100, 1].max
        self.recover_hp[user] += rand(amp+1) + rand(amp+1) - amp
      end
      if item.variance > 0 and self.recover_sp[user].abs > 0
        amp = [self.recover_sp[user].abs * item.variance / 100, 1].max
        self.recover_sp[user] += rand(amp+1) + rand(amp+1) - amp
      end
      # 回復量の符号が負の場合
      if self.recover_hp[user] < 0
        # 防御修正
        if self.guarding?
          self.recover_hp[user] /= 2
        end
      end
      # HP 回復量の符号を反転し、ダメージの値に設定
      self.damage[user] = -self.recover_hp[user]
      # HP および SP の変動判定
      last_hp = [[self.hp + self.recover_hp[user], self.maxhp].min, 0].max
      last_sp = [[self.sp + self.recover_sp[user], self.maxsp].min, 0].max
      effective |= self.hp != last_hp
      effective |= self.sp != last_sp
      # ステート変化
      @state_changed = false
      effective |= states_plus(user, item.plus_state_set)
      effective |= states_minus(user, item.minus_state_set)
      unless $game_temp.in_battle
        self.damage_effect(user, 2)
      end
      # パラメータ上昇値が有効の場合
      if item.parameter_type > 0 and item.parameter_points != 0
        # パラメータで分岐
        case item.parameter_type
        when 1  # MaxHP
          @maxhp_plus += item.parameter_points
        when 2  # MaxSP
          @maxsp_plus += item.parameter_points
        when 3  # 腕力
          @str_plus += item.parameter_points
        when 4  # 器用さ
          @dex_plus += item.parameter_points
        when 5  # 素早さ
          @agi_plus += item.parameter_points
        when 6  # 魔力
          @int_plus += item.parameter_points
        end
        # 有効フラグをセット
        effective = true
      end
      # HP 回復率と回復量が 0 の場合
      if item.recover_hp_rate == 0 and item.recover_hp == 0
        # ダメージに空文字列を設定
        self.damage[user] = ""
        # SP 回復率と回復量が 0、パラメータ上昇値が無効の場合
        if item.recover_sp_rate == 0 and item.recover_sp == 0 and
           (item.parameter_type == 0 or item.parameter_points == 0)
          # ステートに変化がない場合
          unless @state_changed
            # ダメージに "Miss" を設定
            self.damage[user] = "Miss"
          end
        end
      end
    # ミスの場合
    else
      # ダメージに "Miss" を設定
      self.damage[user] = "Miss"
    end
    # 戦闘中でない場合
    unless $game_temp.in_battle
      # ダメージに nil を設定
      self.damage[user] = nil
    end
    # メソッド終了
    return effective
  end
  #--------------------------------------------------------------------------
  # ● ステート変化 (+) の適用
  #     plus_state_set  : ステート変化 (+)
  #--------------------------------------------------------------------------
  def states_plus(battler, plus_state_set)
    # 有効フラグをクリア
    effective = false
    # ループ (付加するステート)
    for i in plus_state_set
      # このステートが防御されていない場合
      unless self.state_guard?(i)
        # このステートがフルでなければ有効フラグをセット
        effective |= self.state_full?(i) == false
        # ステートが [抵抗しない] の場合
        if $data_states[i].nonresistance
          # ステート変化フラグをセット
          @state_changed = true
          # ステートを付加
          self.state_p[battler].push(i)
        # このステートがフルではない場合
        elsif self.state_full?(i) == false
          # ステート有効度を確率に変換し、乱数と比較
          if rand(100) < [0,100,80,60,40,20,0][self.state_ranks[i]]
            # ステート変化フラグをセット
            @state_changed = true
            # ステートを付加
            self.state_p[battler].push(i)
          end
        end
      end
    end
    # メソッド終了
    return effective
  end
  #--------------------------------------------------------------------------
  # ● ステート変化 (-) の適用
  #     minus_state_set : ステート変化 (-)
  #--------------------------------------------------------------------------
  def states_minus(battler, minus_state_set)
    # 有効フラグをクリア
    effective = false
    # ループ (解除するステート)
    for i in minus_state_set
      # このステートが付加されていれば有効フラグをセット
      effective |= self.state?(i)
      # ステート変化フラグをセット
      @state_changed = true
      # ステートを解除
      self.state_m[battler].push(i)
    end
    # メソッド終了
    return effective
  end
  #--------------------------------------------------------------------------
  # ● ダメージ演算
  #--------------------------------------------------------------------------
  def damage_effect(battler, item)
    if item == 2
      self.hp += self.recover_hp[battler]
      self.sp += self.recover_sp[battler]
      if self.recover_sp[battler] != 0
        self.damage_sp[battler] = -self.recover_sp[battler]
      end
      self.recover_hp.delete(battler)
      self.recover_sp.delete(battler)
    else
      if self.damage[battler].class != String
        self.hp -= self.damage[battler]
      end
    end
    for i in self.state_p[battler]
      add_state(i)
    end
    for i in self.state_m[battler]
      remove_state(i)
    end
  end
  #--------------------------------------------------------------------------
  # ● スリップダメージの効果適用
  #--------------------------------------------------------------------------
  def slip_damage_effect
    # ダメージを設定
    self.damage["slip"] = self.maxhp / 10
    # 分散
    if self.damage["slip"].abs > 0
      amp = [self.damage["slip"].abs * 15 / 100, 1].max
      self.damage["slip"] += rand(amp+1) + rand(amp+1) - amp
    end
    # HP からダメージを減算
    self.hp -= self.damage["slip"]
    # メソッド終了
    return true
  end
end

#==============================================================================
# ■ Game_BattleAction
#------------------------------------------------------------------------------
# 　アクション (戦闘中の行動) を扱うクラスです。このクラスは Game_Battler クラ
# スの内部で使用されます。
#==============================================================================

class Game_BattleAction
  #--------------------------------------------------------------------------
  # ● 公開インスタンス変数
  #--------------------------------------------------------------------------
  attr_accessor :spell_id                 # 合体魔法用スキル ID
  attr_accessor :force_kind               # 種別 (基本 / スキル / アイテム)
  attr_accessor :force_basic              # 基本 (攻撃 / 防御 / 逃げる)
  attr_accessor :force_skill_id           # スキル ID
  #--------------------------------------------------------------------------
  # ● 有効判定
  #--------------------------------------------------------------------------
  def valid?
    return (not (@force_kind == 0 and @force_basic == 3))
  end
end

#==============================================================================
# ■ Game_Actor
#------------------------------------------------------------------------------
# 　アクターを扱うクラスです。このクラスは Game_Actors クラス ($game_actors)
# の内部で使用され、Game_Party クラス ($game_party) からも参照されます。
#==============================================================================

class Game_Actor < Game_Battler
  def skill_can_use?(skill_id)
    return super
  end
end

#==============================================================================
# ■ Game_Enemy
#------------------------------------------------------------------------------
# 　エネミーを扱うクラスです。このクラスは Game_Troop クラス ($game_troop) の
# 内部で使用されます。
#==============================================================================

class Game_Enemy < Game_Battler
  #--------------------------------------------------------------------------
  # ● 公開インスタンス変数
  #--------------------------------------------------------------------------
  attr_accessor :height                  # 画像の高さ
  attr_accessor :real_x                  # X座標補正
  attr_accessor :real_y                  # Y座標補正
  attr_accessor :real_zoom               # 拡大率
  #--------------------------------------------------------------------------
  # ● オブジェクト初期化
  #     troop_id     : トループ ID
  #     member_index : トループメンバーのインデックス
  #--------------------------------------------------------------------------
  def initialize(troop_id, member_index)
    super()
    @troop_id = troop_id
    @member_index = member_index
    troop = $data_troops[@troop_id]
    @enemy_id = troop.members[@member_index].enemy_id
    enemy = $data_enemies[@enemy_id]
    @battler_name = enemy.battler_name
    @battler_hue = enemy.battler_hue
    @hp = maxhp
    @sp = maxsp
    @real_x = 0
    @real_y = 0
    @real_zoom = 1.0
    @fly = 0
    enemy.name.sub(/\\[Ff]\[([0-9]+)\]/) {@fly = $1.to_i}
    @hidden = troop.members[@member_index].hidden
    @immortal = troop.members[@member_index].immortal
  end
  alias :true_x :screen_x
  alias :true_y :screen_y
  #--------------------------------------------------------------------------
  # ● バトル画面 X 座標の取得
  #--------------------------------------------------------------------------
  def screen_x
    return 320 + (true_x - 320) * @real_zoom + @real_x
  end
  #--------------------------------------------------------------------------
  # ● バトル画面 Y 座標の取得
  #--------------------------------------------------------------------------
  def screen_y
    return true_y * @real_zoom + @real_y
  end
  #--------------------------------------------------------------------------
  # ● バトル画面 Z 座標の取得
  #--------------------------------------------------------------------------
  def screen_z
    return true_y + @fly
  end
  #--------------------------------------------------------------------------
  # ● バトル画面 拡大率の取得
  #--------------------------------------------------------------------------
  def zoom
    return ($scene.zoom_rate[1] - $scene.zoom_rate[0]) *
                          (true_y + @fly) / 320 + $scene.zoom_rate[0]
  end
  #--------------------------------------------------------------------------
  # ● 攻撃用、バトル画面 X 座標の取得
  #--------------------------------------------------------------------------
  def attack_x(z)
    return (320 - true_x) * z * 0.75
  end
  #--------------------------------------------------------------------------
  # ● 攻撃用、バトル画面 Y 座標の取得
  #--------------------------------------------------------------------------
  def attack_y(z)
    return (160 - (true_y + @fly / 4) * z + @height * zoom * z / 2) * 0.75
  end
  #--------------------------------------------------------------------------
  # ● アクション作成
  #--------------------------------------------------------------------------
  def make_action
    # カレントアクションをクリア
    self.current_action.clear
    # 動けない場合
    unless self.inputable?
      # メソッド終了
      return
    end
    # 現在有効なアクションを抽出
    available_actions = []
    rating_max = 0
    for action in self.actions
      # ターン 条件確認
      n = $game_temp.battle_turn
      a = action.condition_turn_a
      b = action.condition_turn_b
      if (b == 0 and n != a) or
         (b > 0 and (n < 1 or n < a or n % b != a % b))
        next
      end
      # HP 条件確認
      if self.hp * 100.0 / self.maxhp > action.condition_hp
        next
      end
      # レベル 条件確認
      if $game_party.max_level < action.condition_level
        next
      end
      # スイッチ 条件確認
      switch_id = action.condition_switch_id
      if switch_id > 0 and $game_switches[switch_id] == false
        next
      end
      # スキル使用可能 条件確認
      if action.kind == 1
        unless self.skill_can_use?(action.skill_id)
          next
        end
      end
      # 条件に該当 : このアクションを追加
      available_actions.push(action)
      if action.rating > rating_max
        rating_max = action.rating
      end
    end
    # 最大のレーティング値を 3 として合計を計算 (0 以下は除外)
    ratings_total = 0
    for action in available_actions
      if action.rating > rating_max - 3
        ratings_total += action.rating - (rating_max - 3)
      end
    end
    # レーティングの合計が 0 ではない場合
    if ratings_total > 0
      # 乱数を作成
      value = rand(ratings_total)
      # 作成した乱数に対応するものをカレントアクションに設定
      for action in available_actions
        if action.rating > rating_max - 3
          if value < action.rating - (rating_max - 3)
            self.current_action.kind = action.kind
            self.current_action.basic = action.basic
            self.current_action.skill_id = action.skill_id
            self.current_action.decide_random_target_for_enemy
            return
          else
            value -= action.rating - (rating_max - 3)
          end
        end
      end
    end
  end
end

#==============================================================================
# ■ Game_Party
#------------------------------------------------------------------------------
# 　パーティを扱うクラスです。ゴールドやアイテムなどの情報が含まれます。このク
# ラスのインスタンスは $game_party で参照されます。
#==============================================================================

class Game_Party
  #--------------------------------------------------------------------------
  # ● 全滅判定
  #--------------------------------------------------------------------------
  def all_dead?
    # パーティ人数が 0 人の場合
    if $game_party.actors.size == 0
      return false
    end
    # HP 0 以上のアクターがパーティにいる場合
    for actor in @actors
      if actor.rest_hp > 0
        return false
      end
    end
    # 全滅
    return true
  end
  #--------------------------------------------------------------------------
  # ● 対象アクターのランダムな決定
  #     hp0 : HP 0 のアクターに限る
  #--------------------------------------------------------------------------
  # オリジナルのターゲット決定ルーチンを smooth_target_actor_rtab と名前変更
  alias :random_target_actor_rtab :random_target_actor
  def random_target_actor(hp0 = false)
    # ルーレットを初期化
    roulette = []
    # ループ
    for actor in @actors
      # 条件に該当する場合
      if (not hp0 and actor.exist? and actor.rest_hp > 0) or
          (hp0 and actor.hp0?)
        # アクターのクラスの [位置] を取得
        position = $data_classes[actor.class_id].position
        # 前衛のとき n = 4、中衛のとき n = 3、後衛のとき n = 2
        n = 4 - position
        # ルーレットにアクターを n 回追加
        n.times do
          roulette.push(actor)
        end
      end
    end
    # ルーレットのサイズが 0 の場合
    if roulette.size == 0
      return random_target_actor_rtab(hp0)
    end
    # ルーレットを回し、アクターを決定
    return roulette[rand(roulette.size)]
  end
  #--------------------------------------------------------------------------
  # ● 対象アクターのスムーズな決定
  #     actor_index : アクターインデックス
  #--------------------------------------------------------------------------
  # オリジナルのターゲット決定ルーチンを smooth_target_actor_rtab と名前変更
  alias :smooth_target_actor_rtab :smooth_target_actor
  def smooth_target_actor(actor_index)
    # アクターを取得
    actor = @actors[actor_index]
    # アクターが存在する場合
    if actor != nil and actor.exist? and actor.rest_hp > 0
      return actor
    end
    # ループ
    for actor in @actors
      # アクターが存在する場合
      if actor.exist? and actor.rest_hp > 0
        return actor
      end
    end
    # 味方が全滅している場合、オリジナルのターゲット決定ルーチンを実行する
    return smooth_target_actor_rtab(actor_index)
  end
end

#==============================================================================
# ■ Game_Troop
#------------------------------------------------------------------------------
# 　トループを扱うクラスです。このクラスのインスタンスは $game_troop で参照さ
# れます。
#==============================================================================

class Game_Troop
  #--------------------------------------------------------------------------
  # ● 対象エネミーのランダムな決定
  #     hp0 : HP 0 のエネミーに限る
  #--------------------------------------------------------------------------
  # オリジナルのターゲット決定ルーチンを random_target_enemy_rtab と名前変更
  alias :random_target_enemy_rtab :random_target_enemy
  def random_target_enemy(hp0 = false)
    # ルーレットを初期化
    roulette = []
    # ループ
    for enemy in @enemies
      # 条件に該当する場合
      if (not hp0 and enemy.exist? and enemy.rest_hp > 0) or
          (hp0 and enemy.hp0?)
        # ルーレットにエネミーを追加
        roulette.push(enemy)
      end
    end
    # ルーレットのサイズが 0 の場合
    if roulette.size == 0
      return random_target_enemy_rtab(hp0)
    end
    # ルーレットを回し、エネミーを決定
    return roulette[rand(roulette.size)]
  end
  #--------------------------------------------------------------------------
  # ● 対象エネミーのスムーズな決定
  #     enemy_index : エネミーインデックス
  #--------------------------------------------------------------------------
  # オリジナルのターゲット決定ルーチンを smooth_target_enemy_rtab と名前変更
  alias :smooth_target_enemy_rtab :smooth_target_enemy
  def smooth_target_enemy(enemy_index)
    # エネミーを取得
    enemy = @enemies[enemy_index]
    # エネミーが存在する場合
    if enemy != nil and enemy.exist? and enemy.rest_hp > 0
      return enemy
    end
    # ループ
    for enemy in @enemies
      # エネミーが存在する場合
      if enemy.exist? and enemy.rest_hp > 0
        return enemy
      end
    end
    # 敵が全滅している場合、再度敵の検索を行う
    return smooth_target_enemy_rtab(enemy_index)
  end
end

#==============================================================================
# ■ Sprite_Battler
#------------------------------------------------------------------------------
# 　バトラー表示用のスプライトです。Game_Battler クラスのインスタンスを監視し、
# スプライトの状態を自動的に変化させます。
#==============================================================================

class Sprite_Battler < RPG::Sprite
  #--------------------------------------------------------------------------
  # ● フレーム更新
  #--------------------------------------------------------------------------
  def update
    super
    # バトラーが nil の場合
    if @battler == nil
      self.bitmap = nil
      loop_animation(nil)
      return
    end
    # ファイル名か色相が現在のものと異なる場合
    if @battler.battler_name != @battler_name or
       @battler.battler_hue != @battler_hue
      # ビットマップを取得、設定
      @battler_name = @battler.battler_name
      @battler_hue = @battler.battler_hue
      self.bitmap = RPG::Cache.battler(@battler_name, @battler_hue)
      @width = bitmap.width
      @height = bitmap.height
      self.ox = @width / 2
      self.oy = @height
      if @battler.is_a?(Game_Enemy)
        @battler.height = @height
      end
      # 戦闘不能または隠れ状態なら不透明度を 0 にする
      if @battler.dead? or @battler.hidden
        self.opacity = 0
      end
    end
    # アニメーション ID が現在のものと異なる場合
    if @battler.state_animation_id != @state_animation_id
      @state_animation_id = @battler.state_animation_id
      loop_animation($data_animations[@state_animation_id])
    end
    # 表示されるべきアクターの場合
    if @battler.is_a?(Game_Actor) and @battler_visible
      # メインフェーズでないときは不透明度をやや下げる
      if $game_temp.battle_main_phase
        self.opacity += 3 if self.opacity < 255
      else
        self.opacity -= 3 if self.opacity > 207
      end
    end
    # 明滅
    if @battler.blink
      blink_on
    else
      blink_off
    end
    # 不可視の場合
    unless @battler_visible
      # 出現
      if not @battler.hidden and not @battler.dead? and
         (@battler.damage.size < 2 or @battler.damage_pop.size < 2)
        appear
        @battler_visible = true
      end
    end
    # ダメージ
    for battler in @battler.damage_pop
      if battler[0].class == Array
        if battler[0][1] >= 0
          $scene.skill_se
        else
          $scene.levelup_se
        end
        damage(@battler.damage[battler[0]], false, 2)
      else
        damage(@battler.damage[battler[0]], @battler.critical[battler[0]])
      end
      if @battler.damage_sp.include?(battler[0])
        damage(@battler.damage_sp[battler[0]],
                @battler.critical[battler[0]], 1)
        @battler.damage_sp.delete(battler[0])
      end
      @battler.damage_pop.delete(battler[0])
      @battler.damage.delete(battler[0])
      @battler.critical.delete(battler[0])
    end
    # 可視の場合
    if @battler_visible
      # 逃走
      if @battler.hidden
        $game_system.se_play($data_system.escape_se)
        escape
        @battler_visible = false
      end
      # 白フラッシュ
      if @battler.white_flash
        whiten
        @battler.white_flash = false
      end
      # アニメーション
      unless @battler.animation.empty?
        for animation in @battler.animation.reverse
          animation($data_animations[animation[0]], animation[1])
          @battler.animation.delete(animation)
        end
      end
      # コラプス
      if @battler.damage.empty? and @battler.dead?
        if $scene.dead_ok?(@battler)
          if @battler.is_a?(Game_Enemy)
            $game_system.se_play($data_system.enemy_collapse_se)
          else
            $game_system.se_play($data_system.actor_collapse_se)
          end
          collapse
          @battler_visible = false
        end
      end
    end
    # スプライトの座標を設定
    self.x = @battler.screen_x
    self.y = @battler.screen_y
    self.z = @battler.screen_z
    if @battler.is_a?(Game_Enemy)
      self.zoom_x = @battler.real_zoom * @battler.zoom
      self.zoom_y = @battler.real_zoom * @battler.zoom
    end
  end
end

#==============================================================================
# ■ Window_Base
#------------------------------------------------------------------------------
# 　ゲーム中のすべてのウィンドウのスーパークラスです。
#==============================================================================

class Window_Base < Window
  #--------------------------------------------------------------------------
  # ● ゲージの描画
  #--------------------------------------------------------------------------
  def gauge_rect_at(width, height, align3,
                    color1, color2, color3, color4, color5, color6, color7,
                    color8, color9, color10, color11, color12, grade1, grade2)
    # 枠描画
    @at_gauge = Bitmap.new(width, height * 5)
    @at_gauge.fill_rect(0, 0, width, height, color1)
    @at_gauge.fill_rect(1, 1, width - 2, height - 2, color2)
    if (align3 == 1 and grade1 == 0) or grade1 > 0
      color = color3
      color3 = color4
      color4 = color
    end
    if (align3 == 1 and grade2 == 0) or grade2 > 0
      color = color5
      color5 = color6
      color6 = color
      color = color7
      color7 = color8
      color8 = color
      color = color9
      color9 = color10
      color10 = color
      color = color11
      color11 = color12
      color12 = color
    end
    if align3 == 0
      if grade1 == 2
        grade1 = 3
      end
      if grade2 == 2
        grade2 = 3
      end
    end
    # 空ゲージの描画 縦にグラデーション表示
    @at_gauge.gradation_rect(2, 2, width - 4, height - 4,
                                  color3, color4, grade1)
    # 実ゲージの描画
    @at_gauge.gradation_rect(2, height + 2, width- 4, height - 4,
                                  color5, color6, grade2)
    @at_gauge.gradation_rect(2, height * 2 + 2, width- 4, height - 4,
                                  color7, color8, grade2)
    @at_gauge.gradation_rect(2, height * 3 + 2, width- 4, height - 4,
                                  color9, color10, grade2)
    @at_gauge.gradation_rect(2, height * 4 + 2, width- 4, height - 4,
                                  color11, color12, grade2)
  end
end

#==============================================================================
# ■ Window_Help
#------------------------------------------------------------------------------
# 　スキルやアイテムの説明、アクターのステータスなどを表示するウィンドウです。
#==============================================================================

class Window_Help < Window_Base
  #--------------------------------------------------------------------------
  # ● エネミー設定
  #     enemy : 名前とステートを表示するエネミー
  #--------------------------------------------------------------------------
  def set_enemy(enemy)
    text = enemy.name.sub(/\\[Ff]\[([0-9]+)\]/) {""}
    state_text = make_battler_state_text(enemy, 112, false)
    if state_text != ""
      text += "  " + state_text
    end
    set_text(text, 1)
  end
end

#==============================================================================
# ■ Window_BattleStatus
#------------------------------------------------------------------------------
# 　バトル画面でパーティメンバーのステータスを表示するウィンドウです。
#==============================================================================

class Window_BattleStatus < Window_Base
  #--------------------------------------------------------------------------
  # ● オブジェクト初期化
  #--------------------------------------------------------------------------
  def initialize
    x = (4 - $game_party.actors.size) * 80
    width = $game_party.actors.size * 160
    super(x, 320, width, 160)
    self.back_opacity = 160
    @actor_window = []
    for i in 0...$game_party.actors.size
      @actor_window.push(Window_ActorStatus.new(i, x + i * 160))
    end
    @level_up_flags = [false, false, false, false]
    refresh
  end
  #--------------------------------------------------------------------------
  # ● 解放
  #--------------------------------------------------------------------------
  def dispose
    for window in @actor_window
      window.dispose
    end
    super
  end
  #--------------------------------------------------------------------------
  # ● リフレッシュ
  #--------------------------------------------------------------------------
  def refresh(number = 0)
    if number == 0
      cnt = 0
      for window in @actor_window
        window.refresh(@level_up_flags[cnt])
        cnt += 1
      end
    else
      @actor_window[number - 1].refresh(@level_up_flags[number - 1])
    end
  end
  #--------------------------------------------------------------------------
  # ● ATゲージリフレッシュ
  #--------------------------------------------------------------------------
  def at_refresh(number = 0)
    if number == 0
      for window in @actor_window
        window.at_refresh
      end
    else
      @actor_window[number - 1].at_refresh
    end
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新
  #--------------------------------------------------------------------------
  def update
    super
    if self.x != (4 - $game_party.actors.size) * 80
      self.x = (4 - $game_party.actors.size) * 80
      self.width = $game_party.actors.size * 160
      for window in @actor_window
        window.dispose
      end
      @actor_window = []
      for i in 0...$game_party.actors.size
        @actor_window.push(Window_ActorStatus.new(i, x + i * 160))
      end
      refresh
    end
    for window in @actor_window
      window.update
    end
  end
end

#==============================================================================
# ■ Window_ActorStatus
#------------------------------------------------------------------------------
# 　バトル画面でパーティメンバーのステータスをそれぞれ表示するウィンドウです。
#==============================================================================

class Window_ActorStatus < Window_Base
  #--------------------------------------------------------------------------
  # ● オブジェクト初期化
  #--------------------------------------------------------------------------
  def initialize(id, x)
    @actor_num = id
    super(x, 320, 160, 160)
    self.contents = Bitmap.new(width - 32, height - 32)
    self.opacity = 0
    self.back_opacity = 0
    actor = $game_party.actors[@actor_num]
    @actor_nm = actor.name
    @actor_mhp = actor.maxhp
    @actor_msp = actor.maxsp
    @actor_hp = actor.hp
    @actor_sp = actor.sp
    @actor_st = make_battler_state_text(actor, 120, true)
    @status_window = []
    for i in 0...5
      @status_window.push(Window_DetailsStatus.new(actor, i, x))
    end
    refresh(false)
  end
  #--------------------------------------------------------------------------
  # ● 解放
  #--------------------------------------------------------------------------
  def dispose
    for i in 0...5
      @status_window[i].dispose
    end
    super
  end
  #--------------------------------------------------------------------------
  # ● リフレッシュ
  #--------------------------------------------------------------------------
  def refresh(level_up_flags)
    self.contents.clear
    actor = $game_party.actors[@actor_num]
    @status_window[0].refresh(actor) if @actor_nm != actor.name
    @status_window[1].refresh(actor) if
      @actor_mhp != actor.maxhp or @actor_hp != actor.hp
    @status_window[2].refresh(actor) if
      @actor_msp != actor.maxsp or @actor_sp != actor.sp
    @status_window[3].refresh(actor, level_up_flags) if
      @actor_st != make_battler_state_text(actor, 120, true) or level_up_flags
    @actor_nm = actor.name
    @actor_mhp = actor.maxhp
    @actor_msp = actor.maxsp
    @actor_hp = actor.hp
    @actor_sp = actor.sp
    @actor_st = make_battler_state_text(actor, 120, true)
  end
  #--------------------------------------------------------------------------
  # ● ATゲージリフレッシュ
  #--------------------------------------------------------------------------
  def at_refresh
    @status_window[4].refresh($game_party.actors[@actor_num])
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新
  #--------------------------------------------------------------------------
  def update
    for window in @status_window
      window.update
    end
  end
end

#==============================================================================
# ■ Window_DetailsStatus
#------------------------------------------------------------------------------
# 　バトル画面でアクターのステータスを個々に表示するウィンドウです。
#==============================================================================

class Window_DetailsStatus < Window_Base
  #--------------------------------------------------------------------------
  # ● オブジェクト初期化
  #--------------------------------------------------------------------------
  def initialize(actor, id, x)
    @status_id = id
    super(x, 320 + id * 26, 160, 64)
    self.contents = Bitmap.new(width - 32, height - 32)
    self.opacity = 0
    self.back_opacity = 0
    refresh(actor, false)
  end
  #--------------------------------------------------------------------------
  # ● 解放
  #--------------------------------------------------------------------------
  def dispose
    super
  end
  #--------------------------------------------------------------------------
  # ● リフレッシュ
  #--------------------------------------------------------------------------
  def refresh(actor, level_up_flags = false)
    self.contents.clear
    case @status_id
    when 0
      draw_actor_name(actor, 4, 0)
    when 1
      draw_actor_hp(actor, 4, 0, 120)
    when 2
      draw_actor_sp(actor, 4, 0, 120)
    when 3
      if level_up_flags
        self.contents.font.color = normal_color
        self.contents.draw_text(4, 0, 120, 32, "LEVEL UP!")
      else
        draw_actor_state(actor, 4, 0)
      end
    when 4
      draw_actor_atg(actor, 4, 0, 120)
    end
  end
  #--------------------------------------------------------------------------
  # ● フレーム更新
  #--------------------------------------------------------------------------
  def update
    # メインフェーズのときは不透明度をやや下げる
    if $game_temp.battle_main_phase
      self.contents_opacity -= 4 if self.contents_opacity > 191
    else
      self.contents_opacity += 4 if self.contents_opacity < 255
    end
  end
end

#==============================================================================
# ■ Arrow_Base
#------------------------------------------------------------------------------
# 　バトル画面で使用するアローカーソル表示用のスプライトです。このクラスは
# Arrow_Enemy クラスと Arrow_Actor クラスのスーパークラスとして使用されます。
#==============================================================================

class Arrow_Base < Sprite
  #--------------------------------------------------------------------------
  # ● オブジェクト初期化
  #     viewport : ビューポート
  #--------------------------------------------------------------------------
  def initialize(viewport)
    super(viewport)
    self.bitmap = RPG::Cache.windowskin($game_system.windowskin_name)
    self.ox = 16
    self.oy = 32
    self.z = 2500
    @blink_count = 0
    @index = 0
    @help_window = nil
    update
  end
end

#==============================================================================
# ■ Arrow_Enemy
#------------------------------------------------------------------------------
# 　エネミーを選択させるためのアローカーソルです。このクラスは Arrow_Base クラ
# スを継承します。
#==============================================================================

class Arrow_Enemy < Arrow_Base
  #--------------------------------------------------------------------------
  # ● フレーム更新
  #--------------------------------------------------------------------------
  def update
    super
    # 存在しないエネミーを指していたら飛ばす
    $game_troop.enemies.size.times do
      break if self.enemy.exist?
      @index += 1
      @index %= $game_troop.enemies.size
    end
    # カーソル右
    if Input.repeat?(Input::RIGHT)
      $game_system.se_play($data_system.cursor_se)
      $game_troop.enemies.size.times do
        @index += 1
        @index %= $game_troop.enemies.size
        break if self.enemy.exist?
      end
      $scene.camera = "select"
      zoom = 1 / self.enemy.zoom
      $scene.spriteset.screen_target(self.enemy.attack_x(zoom) * 0.75,
                                      self.enemy.attack_y(zoom) * 0.75, zoom)
    end
    # カーソル左
    if Input.repeat?(Input::LEFT)
      $game_system.se_play($data_system.cursor_se)
      $game_troop.enemies.size.times do
        @index += $game_troop.enemies.size - 1
        @index %= $game_troop.enemies.size
        break if self.enemy.exist?
      end
      $scene.camera = "select"
      zoom = 1 / self.enemy.zoom
      $scene.spriteset.screen_target(self.enemy.attack_x(zoom) * 0.75,
                                      self.enemy.attack_y(zoom) * 0.75, zoom)
    end
    # スプライトの座標を設定
    if self.enemy != nil
      self.x = self.enemy.screen_x
      self.y = self.enemy.screen_y
    end
  end
end

#==============================================================================
# ■ Interpreter
#------------------------------------------------------------------------------
# 　イベントコマンドを実行するインタプリタです。このクラスは Game_System クラ
# スや Game_Event クラスの内部で使用されます。
#==============================================================================

class Interpreter
  #--------------------------------------------------------------------------
  # ● アクターの入れ替え
  #--------------------------------------------------------------------------
  def command_129
    # アクターを取得
    actor = $game_actors[@parameters[0]]
    # アクターが有効の場合
    if actor != nil
      # 操作で分岐
      if @parameters[1] == 0
        if @parameters[2] == 1
          $game_actors[@parameters[0]].setup(@parameters[0])
        end
        $game_party.add_actor(@parameters[0])
        if $game_temp.in_battle
          $game_actors[@parameters[0]].at = 0
          $game_actors[@parameters[0]].atp = 0
          $scene.spell_reset($game_actors[@parameters[0]])
          $game_actors[@parameters[0]].damage_pop = {}
          $game_actors[@parameters[0]].damage = {}
          $game_actors[@parameters[0]].damage_sp = {}
          $game_actors[@parameters[0]].critical = {}
          $game_actors[@parameters[0]].recover_hp = {}
          $game_actors[@parameters[0]].recover_sp = {}
          $game_actors[@parameters[0]].state_p = {}
          $game_actors[@parameters[0]].state_m = {}
          $game_actors[@parameters[0]].animation = []
        end
      else
        $game_party.remove_actor(@parameters[0])
      end
    end
    if $game_temp.in_battle
      $scene.status_window.update
    end
    # 継続
    return true
  end
  #--------------------------------------------------------------------------
  # ● HP の増減
  #--------------------------------------------------------------------------
  alias :command_311_rtab :command_311
  def command_311
    command_311_rtab
    if $game_temp.in_battle
      $scene.status_window.refresh
    end
  end
  #--------------------------------------------------------------------------
  # ● SP の増減
  #--------------------------------------------------------------------------
  alias :command_312_rtab :command_312
  def command_312
    command_312_rtab
    if $game_temp.in_battle
      $scene.status_window.refresh
    end
  end
  #--------------------------------------------------------------------------
  # ● ステートの変更
  #--------------------------------------------------------------------------
  alias :command_313_rtab :command_313
  def command_313
    command_313_rtab
    if $game_temp.in_battle
      $scene.status_window.refresh
    end
  end
  #--------------------------------------------------------------------------
  # ● 全回復
  #--------------------------------------------------------------------------
  alias :command_314_rtab :command_314
  def command_314
    command_314_rtab
    if $game_temp.in_battle
      $scene.status_window.refresh
    end
  end
  #--------------------------------------------------------------------------
  # ● EXP の増減
  #--------------------------------------------------------------------------
  alias :command_315_rtab :command_315
  def command_315
    command_315_rtab
    if $game_temp.in_battle
      $scene.status_window.refresh
    end
  end
  #--------------------------------------------------------------------------
  # ● レベルの増減
  #--------------------------------------------------------------------------
  alias :command_316_rtab :command_316
  def command_316
    command_316_rtab
    if $game_temp.in_battle
      $scene.status_window.refresh
    end
  end
  #--------------------------------------------------------------------------
  # ● パラメータの増減
  #--------------------------------------------------------------------------
  alias :command_317_rtab :command_317
  def command_317
    command_317_rtab
    if $game_temp.in_battle
      $scene.status_window.refresh
    end
  end
  #--------------------------------------------------------------------------
  # ● 装備の変更
  #--------------------------------------------------------------------------
  alias :command_319_rtab :command_319
  def command_319
    command_319_rtab
    if $game_temp.in_battle
      $scene.status_window.refresh
    end
  end
  #--------------------------------------------------------------------------
  # ● アクターの名前変更
  #--------------------------------------------------------------------------
  alias :command_320_rtab :command_320
  def command_320
    command_320_rtab
    if $game_temp.in_battle
      $scene.status_window.refresh
    end
  end
  #--------------------------------------------------------------------------
  # ● アクターのクラス変更
  #--------------------------------------------------------------------------
  alias :command_321_rtab :command_321
  def command_321
    command_321_rtab
    if $game_temp.in_battle
      $scene.status_window.refresh
    end
  end
  #--------------------------------------------------------------------------
  # ● アニメーションの表示
  #--------------------------------------------------------------------------
  def command_337
    # イテレータで処理
    iterate_battler(@parameters[0], @parameters[1]) do |battler|
      # バトラーが存在する場合
      if battler.exist?
        # アニメーション ID を設定
        battler.animation.push([@parameters[2], true])
      end
    end
    # 継続
    return true
  end
  #--------------------------------------------------------------------------
  # ● ダメージの処理
  #--------------------------------------------------------------------------
  def command_338
    # 操作する値を取得
    value = operate_value(0, @parameters[2], @parameters[3])
    # イテレータで処理
    iterate_battler(@parameters[0], @parameters[1]) do |battler|
      # バトラーが存在する場合
      if battler.exist?
        # HP を変更
        battler.hp -= value
        # 戦闘中なら
        if $game_temp.in_battle
          # ダメージを設定
          battler.damage["event"] = value
          battler.damage_pop["event"] = true
        end
      end
    end
    if $game_temp.in_battle
      $scene.status_window.refresh
    end
    # 継続
    return true
  end
  #--------------------------------------------------------------------------
  # ● アクションの強制
  #--------------------------------------------------------------------------
  def command_339
    # 戦闘中でなければ無視
    unless $game_temp.in_battle
      return true
    end
    # ターン数が 0 なら無視
    if $game_temp.battle_turn == 0
      return true
    end
    # イテレータで処理 (便宜的なもので、複数になることはない)
    iterate_battler(@parameters[0], @parameters[1]) do |battler|
      # バトラーが存在する場合
      if battler.exist?
        # アクションを設定
        battler.current_action.force_kind = @parameters[2]
        if battler.current_action.force_kind == 0
          battler.current_action.force_basic = @parameters[3]
        else
          battler.current_action.force_skill_id = @parameters[3]
        end
        # 行動対象を設定
        if @parameters[4] == -2
          if battler.is_a?(Game_Enemy)
            battler.current_action.decide_last_target_for_enemy
          else
            battler.current_action.decide_last_target_for_actor
          end
        elsif @parameters[4] == -1
          if battler.is_a?(Game_Enemy)
            battler.current_action.decide_random_target_for_enemy
          else
            battler.current_action.decide_random_target_for_actor
          end
        elsif @parameters[4] >= 0
          battler.current_action.target_index = @parameters[4]
        end
        # アクションが有効かつ [すぐに実行] の場合
        if battler.current_action.valid? and @parameters[5] == 1
          # 強制対象のバトラーを設定
          $game_temp.forcing_battler = battler
          # インデックスを進める
          @index += 1
          # 終了
          return false
        elsif battler.current_action.valid? and @parameters[5] == 0
          battler.current_action.forcing = true
        end
      end
    end
    # 継続
    return true
  end
end

#==============================================================================
# ■ Spriteモジュール
#------------------------------------------------------------------------------
# 　アニメーションの管理を行うモジュールです。
#==============================================================================

module RPG
  class Sprite < ::Sprite
    def initialize(viewport = nil)
      super(viewport)
      @_whiten_duration = 0
      @_appear_duration = 0
      @_escape_duration = 0
      @_collapse_duration = 0
      @_damage = []
      @_animation = []
      @_animation_duration = 0
      @_blink = false
    end
    def damage(value, critical, type = 0)
      if value.is_a?(Numeric)
        damage_string = value.abs.to_s
      else
        damage_string = value.to_s
      end
      bitmap = Bitmap.new(160, 48)
      bitmap.font.name = "Arial Black"
      bitmap.font.size = 32
      bitmap.font.color.set(0, 0, 0)
      bitmap.draw_text(-1, 12-1, 160, 36, damage_string, 1)
      bitmap.draw_text(+1, 12-1, 160, 36, damage_string, 1)
      bitmap.draw_text(-1, 12+1, 160, 36, damage_string, 1)
      bitmap.draw_text(+1, 12+1, 160, 36, damage_string, 1)
      if value.is_a?(Numeric) and value < 0
        if type == 0
          bitmap.font.color.set(176, 255, 144)
        else
          bitmap.font.color.set(176, 144, 255)
        end
      else
        if type == 0
          bitmap.font.color.set(255, 255, 255)
        else
          bitmap.font.color.set(255, 176, 144)
        end
      end
      if type == 2
        bitmap.font.color.set(255, 224, 128)
      end
      bitmap.draw_text(0, 12, 160, 36, damage_string, 1)
      if critical
        string = "CRITICAL"
        bitmap.font.size = 20
        bitmap.font.color.set(0, 0, 0)
        bitmap.draw_text(-1, -1, 160, 20, string, 1)
        bitmap.draw_text(+1, -1, 160, 20, string, 1)
        bitmap.draw_text(-1, +1, 160, 20, string, 1)
        bitmap.draw_text(+1, +1, 160, 20, string, 1)
        bitmap.font.color.set(255, 255, 255)
        bitmap.draw_text(0, 0, 160, 20, string, 1)
      end
      num = @_damage.size
      if type != 2
        @_damage.push([::Sprite.new, 40, 0, rand(40) - 20, rand(30) + 50])
      else
        @_damage.push([::Sprite.new, 40, 0, rand(20) - 10, rand(20) + 60])
      end
      @_damage[num][0].bitmap = bitmap
      @_damage[num][0].ox = 80 + self.viewport.ox
      @_damage[num][0].oy = 20 + self.viewport.oy
      if self.battler.is_a?(Game_Actor)
        @_damage[num][0].x = self.x
        @_damage[num][0].y = self.y - self.oy / 2
      else
        @_damage[num][0].x = self.x + self.viewport.rect.x -
                            self.ox + self.src_rect.width / 2
        @_damage[num][0].y = self.y - self.oy * self.zoom_y / 2 +
                            self.viewport.rect.y
        @_damage[num][0].zoom_x = self.zoom_x
        @_damage[num][0].zoom_y = self.zoom_y
        @_damage[num][0].z = 3000
      end
    end
    def animation(animation, hit)
      return if animation == nil
      num = @_animation.size
      @_animation.push([animation, hit, animation.frame_max, []])
      bitmap = RPG::Cache.animation(animation.animation_name,
                                    animation.animation_hue)
      if @@_reference_count.include?(bitmap)
        @@_reference_count[bitmap] += 1
      else
        @@_reference_count[bitmap] = 1
      end
      if @_animation[num][0].position != 3 or
          not @@_animations.include?(animation)
        for i in 0..15
          sprite = ::Sprite.new
          sprite.bitmap = bitmap
          sprite.visible = false
          @_animation[num][3].push(sprite)
        end
        unless @@_animations.include?(animation)
          @@_animations.push(animation)
        end
      end
      update_animation(@_animation[num])
    end
    def loop_animation(animation)
      return if animation == @_loop_animation
      dispose_loop_animation
      @_loop_animation = animation
      return if @_loop_animation == nil
      @_loop_animation_index = 0
      animation_name = @_loop_animation.animation_name
      animation_hue = @_loop_animation.animation_hue
      bitmap = RPG::Cache.animation(animation_name, animation_hue)
      if @@_reference_count.include?(bitmap)
        @@_reference_count[bitmap] += 1
      else
        @@_reference_count[bitmap] = 1
      end
      @_loop_animation_sprites = []
      for i in 0..15
        sprite = ::Sprite.new
        sprite.bitmap = bitmap
        sprite.visible = false
        @_loop_animation_sprites.push(sprite)
      end
      # update_loop_animation
    end
    def dispose_damage
      for damage in @_damage.reverse
        damage[0].bitmap.dispose
        damage[0].dispose
        @_damage.delete(damage)
      end
    end
    def dispose_animation
      for anime in @_animation.reverse
        sprite = anime[3][0]
        if sprite != nil
          @@_reference_count[sprite.bitmap] -= 1
          if @@_reference_count[sprite.bitmap] == 0
            sprite.bitmap.dispose
          end
        end
        for sprite in anime[3]
          sprite.dispose
        end
        @_animation.delete(anime)
      end
    end
    def effect?
      @_whiten_duration > 0 or
      @_appear_duration > 0 or
      @_escape_duration > 0 or
      @_collapse_duration > 0 or
      @_damage.size == 0 or
      @_animation.size == 0
    end
    def update
      super
      if @_whiten_duration > 0
        @_whiten_duration -= 1
        self.color.alpha = 128 - (16 - @_whiten_duration) * 10
      end
      if @_appear_duration > 0
        @_appear_duration -= 1
        self.opacity = (16 - @_appear_duration) * 16
      end
      if @_escape_duration > 0
        @_escape_duration -= 1
        self.opacity = 256 - (32 - @_escape_duration) * 10
      end
      if @_collapse_duration > 0
        @_collapse_duration -= 1
        self.opacity = 256 - (48 - @_collapse_duration) * 6
      end
      for damage in @_damage
        if damage[1] > 0
          damage[1] -= 1
          damage[4] -= 3
          damage[2] -= damage[4]
          if self.battler.is_a?(Game_Actor)
            damage[0].x = self.x + (40 - damage[1]) * damage[3] / 10
            damage[0].y = self.y - self.oy / 2 + damage[2] / 10
          else
            damage[0].x = self.x + self.viewport.rect.x -
                          self.ox + self.src_rect.width / 2 +
                          (40 - damage[1]) * damage[3] / 10
            damage[0].y = self.y - self.oy * self.zoom_y / 2 +
                          self.viewport.rect.y + damage[2] / 10
            damage[0].zoom_x = self.zoom_x
            damage[0].zoom_y = self.zoom_y
          end
          damage[0].z = 2960 + damage[1]
          damage[0].opacity = 256 - (12 - damage[1]) * 32
          if damage[1] == 0
            damage[0].bitmap.dispose
            damage[0].dispose
            @_damage.delete(damage)
          end
        end
      end
      for anime in @_animation
        if (Graphics.frame_count % 2 == 0)
          anime[2] -= 1
          update_animation(anime)
        end
      end
      if @_loop_animation != nil and (Graphics.frame_count % 2 == 0)
        update_loop_animation
        @_loop_animation_index += 1
        @_loop_animation_index %= @_loop_animation.frame_max
      end
      if @_blink
        @_blink_count = (@_blink_count + 1) % 32
        if @_blink_count < 16
          alpha = (16 - @_blink_count) * 6
        else
          alpha = (@_blink_count - 16) * 6
        end
        self.color.set(255, 255, 255, alpha)
      end
      @@_animations.clear
    end
    def update_animation(anime)
      if anime[2] > 0
        frame_index = anime[0].frame_max - anime[2]
        cell_data = anime[0].frames[frame_index].cell_data
        position = anime[0].position
        animation_set_sprites(anime[3], cell_data, position)
        for timing in anime[0].timings
          if timing.frame == frame_index
            animation_process_timing(timing, anime[1])
          end
        end
      else
        @@_reference_count[anime[3][0].bitmap] -= 1
        if @@_reference_count[anime[3][0].bitmap] == 0
            anime[3][0].bitmap.dispose
        end
        for sprite in anime[3]
          sprite.dispose
        end
        @_animation.delete(anime)
      end
    end
    def animation_set_sprites(sprites, cell_data, position)
      for i in 0..15
        sprite = sprites[i]
        pattern = cell_data[i, 0]
        if sprite == nil or pattern == nil or pattern == -1
          sprite.visible = false if sprite != nil
          next
        end
        sprite.visible = true
        sprite.src_rect.set(pattern % 5 * 192, pattern / 5 * 192, 192, 192)
        if position == 3
          if self.viewport != nil
            sprite.x = self.viewport.rect.width / 2
            if $game_temp.in_battle and self.battler.is_a?(Game_Enemy)
              sprite.y = self.viewport.rect.height - 320
            else
              sprite.y = self.viewport.rect.height - 160
            end
          else
            sprite.x = 320
            sprite.y = 240
          end
        else
          sprite.x = self.x + self.viewport.rect.x -
                      self.ox + self.src_rect.width / 2
          if $game_temp.in_battle and self.battler.is_a?(Game_Enemy)
            sprite.y = self.y - self.oy * self.zoom_y / 2 +
                        self.viewport.rect.y
            if position == 0
              sprite.y -= self.src_rect.height * self.zoom_y / 4
            elsif position == 2
              sprite.y += self.src_rect.height * self.zoom_y / 4
            end
          else
            sprite.y = self.y + self.viewport.rect.y -
                        self.oy + self.src_rect.height / 2
            sprite.y -= self.src_rect.height / 4 if position == 0
            sprite.y += self.src_rect.height / 4 if position == 2
          end
        end
        sprite.x += cell_data[i, 1]
        sprite.y += cell_data[i, 2]
        sprite.z = 2000
        sprite.ox = 96
        sprite.oy = 96
        sprite.zoom_x = cell_data[i, 3] / 100.0
        sprite.zoom_y = cell_data[i, 3] / 100.0
        if position != 3
          sprite.zoom_x *= self.zoom_x
          sprite.zoom_y *= self.zoom_y
        end
        sprite.angle = cell_data[i, 4]
        sprite.mirror = (cell_data[i, 5] == 1)
        sprite.opacity = cell_data[i, 6] * self.opacity / 255.0
        sprite.blend_type = cell_data[i, 7]
      end
    end
    def x=(x)
      sx = x - self.x
      if sx != 0
        for anime in @_animation
          if anime[3] != nil
            for i in 0..15
              anime[3][i].x += sx
            end
          end
        end
        if @_loop_animation_sprites != nil
          for i in 0..15
            @_loop_animation_sprites[i].x += sx
          end
        end
      end
      super
    end
    def y=(y)
      sy = y - self.y
      if sy != 0
        for anime in @_animation
          if anime[3] != nil
            for i in 0..15
              anime[3][i].y += sy
            end
          end
        end
        if @_loop_animation_sprites != nil
          for i in 0..15
            @_loop_animation_sprites[i].y += sy
          end
        end
      end
      super
    end
  end
end

#------------------------------------------------------------------------------
# 　Bitmapクラスに新たな機能を追加します。
#==============================================================================

class Bitmap
  #--------------------------------------------------------------------------
  # ● 矩形をグラデーション表示
  #     color1 : スタートカラー
  #     color2 : エンドカラー
  #     align  :  0:横にグラデーション
  #               1:縦にグラデーション
  #               2:斜めにグラデーション（激重につき注意）
  #--------------------------------------------------------------------------
  def gradation_rect(x, y, width, height, color1, color2, align = 0)
    if align == 0
      for i in x...x + width
        red   = color1.red + (color2.red - color1.red) * (i - x) / (width - 1)
        green = color1.green +
                (color2.green - color1.green) * (i - x) / (width - 1)
        blue  = color1.blue +
                (color2.blue - color1.blue) * (i - x) / (width - 1)
        alpha = color1.alpha +
                (color2.alpha - color1.alpha) * (i - x) / (width - 1)
        color = Color.new(red, green, blue, alpha)
        fill_rect(i, y, 1, height, color)
      end
    elsif align == 1
      for i in y...y + height
        red   = color1.red +
                (color2.red - color1.red) * (i - y) / (height - 1)
        green = color1.green +
                (color2.green - color1.green) * (i - y) / (height - 1)
        blue  = color1.blue +
                (color2.blue - color1.blue) * (i - y) / (height - 1)
        alpha = color1.alpha +
                (color2.alpha - color1.alpha) * (i - y) / (height - 1)
        color = Color.new(red, green, blue, alpha)
        fill_rect(x, i, width, 1, color)
      end
    elsif align == 2
      for i in x...x + width
        for j in y...y + height
          red   = color1.red + (color2.red - color1.red) *
                  ((i - x) / (width - 1.0) + (j - y) / (height - 1.0)) / 2
          green = color1.green + (color2.green - color1.green) *
                  ((i - x) / (width - 1.0) + (j - y) / (height - 1.0)) / 2
          blue  = color1.blue + (color2.blue - color1.blue) *
                  ((i - x) / (width - 1.0) + (j - y) / (height - 1.0)) / 2
          alpha = color1.alpha + (color2.alpha - color1.alpha) *
                  ((i - x) / (width - 1.0) + (j - y) / (height - 1.0)) / 2
          color = Color.new(red, green, blue, alpha)
          set_pixel(i, j, color)
        end
      end
    elsif align == 3
      for i in x...x + width
        for j in y...y + height
          red   = color1.red + (color2.red - color1.red) *
              ((x + width - i) / (width - 1.0) + (j - y) / (height - 1.0)) / 2
          green = color1.green + (color2.green - color1.green) *
              ((x + width - i) / (width - 1.0) + (j - y) / (height - 1.0)) / 2
          blue  = color1.blue + (color2.blue - color1.blue) *
              ((x + width - i) / (width - 1.0) + (j - y) / (height - 1.0)) / 2
          alpha = color1.alpha + (color2.alpha - color1.alpha) *
              ((x + width - i) / (width - 1.0) + (j - y) / (height - 1.0)) / 2
          color = Color.new(red, green, blue, alpha)
          set_pixel(i, j, color)
        end
      end
    end
  end
end
