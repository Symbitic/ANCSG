import Felgo
import QtQuick
import QtTextToSpeech
import "."

GameWindow {
  id: window
  screenHeight: 960
  screenWidth: 640

  //! [Game state and enums]
  // Using an enum to keep track of the current scene offers more type-safety.
  enum GameScene {
    SelectGameMode,
    IntroductionMessage,
    Game,
    GameOver
  }
  // Player movement is handled in function to avoid duplicate code for keyboard and voice input handling.
  enum MoveDirection {
    Up,
    Left,
    Down,
    Right
  }

  // Main comes from the filename: Main.qml
  property int currentScene: Main.GameScene.SelectGameMode
  property bool highContrast: false
  property bool blindMode: false
  property int finalScore: 0

  TextToSpeech {
    id: tts
  }
  //! [Game state and enums]

  //! [Save original theme colors]
  // Store a copy of the original colors to use when High Contrast mode is switched off.
  property color defaultTextColor: null
  property color defaultBackgroundColor: null

  // Use imperative assignment to prevent color values from changing.
  Component.onCompleted: {
    defaultBackgroundColor = Theme.colors.backgroundColor;
    defaultTextColor = Theme.colors.textColor;
  }
  //! [Save original theme colors]

  //! [Toggle High Contrast mode]
  // For visually-impaired users, bright text against a dark background (or vice-versa) is much easier to read.
  onHighContrastChanged: {
    Theme.colors.textColor = highContrast ? "#ffffff" : defaultTextColor;
    Theme.colors.backgroundColor = highContrast ? "#000000" : defaultBackgroundColor;
    Theme.appButton.backgroundColor = "yellow";
    Theme.appButton.textColor = "black";
  }

  Rectangle {
    color: Theme.colors.backgroundColor
    anchors.fill: parent
  }
  //! [Toggle High Contrast mode]

  //! [Scene 1]
  Scene {
    id: selectGameModeScene
    visible: window.currentScene === Main.GameScene.SelectGameMode

    signal traditionalModeSelected()
    signal highContrastModeSelected()
    signal blindModeSelected()

    // Blind mode requires both STT and TTS
    readonly property bool enableBlindModeButton: SpeechToText.recognitionAvailable && tts.state === TextToSpeech.Ready
    // Unhelpful error messages are the worst possible UX. The user should know the reason the game isn't working as expected.
    readonly property string missingRequirement: !SpeechToText.recognitionAvailable ? qsTr("Voice recognition") : 
      tts.state !== TextToSpeech.Ready ? qsTr("Text-to-speech") : ""

    Row {
      id: buttonsRow
      anchors.centerIn: parent
      spacing: dp(10)

      MenuButton {
        text: qsTr("Traditional")
        color: "red"
        buttonText.color: "white"
        buttonText.font.pixelSize: 24
        onClicked: selectGameModeScene.traditionalModeSelected()
      }

      MenuButton {
        text: qsTr("High Contrast")
        color: "green"
        buttonText.color: "white"
        buttonText.font.pixelSize: 24
        onClicked: selectGameModeScene.highContrastModeSelected()
      }

      MenuButton {
        text: qsTr("Blind")
        color: "blue"
        buttonText.color: "white"
        buttonText.font.pixelSize: 24
        onClicked: selectGameModeScene.selectLevelPressed()
        enabled: selectGameModeScene.enableBlindModeButton
        opacity: enabled ? 1.0 : 0.5
      }
    }

    AppText {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: buttonsRow.top
      text: qsTr("Select game mode")
      font.pixelSize: 36
    }

    AppText {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: buttonsRow.bottom
      text: qsTr("%1 unavailable - blind mode disabled").arg(selectGameModeScene.missingRequirement)
      font.pixelSize: 18
      visible: !selectGameModeScene.enableBlindModeButton
    }
  }
  //! [Scene 1]

  //! [Scene 2]
  Scene {
    id: introductionMessageScene
    visible: window.currentScene === Main.GameScene.IntroductionMessage

    signal startClicked()

    readonly property string baseMessage: "Greetings, citizen.\n\n"
      + "You are now part of the underground resistance movement in German-occupied Europe. "
      + "Your goal is to sabotage as many Nazis as you can. "
      + "As detailed in the Simple Sabotage Field Manual, the best way of doing this is to interrupt your coworkers as often as possible."

    readonly property string keyboardInstructions: "Using WASD to move and rotate, visit all the Nazi office workers on your floor and inform them of a meeting they are required to attend."
      + "Afterward, revisit them in the same order to inform them the meeting has been canceled."

    readonly property string voiceInstructions: "Visit all the Nazi office workers on your floor and inform them of a meeting they are required to attend."
      + "Say \"move left, right, up or down\" to move your character."

    readonly property string finalWords: "Good luck!"

    readonly property string text: `${baseMessage} ${window.blindMode ? voiceInstructions : keyboardInstructions}\n\n${finalWords}`

    Column {
      spacing: 0
      width: parent.width - dp(20)
      anchors.centerIn: parent

      AppText {
        text: introductionMessageScene.text
        font.pixelSize: 14
        wrapMode: Text.WordWrap
        width: parent.width
      }

      AppButton {
        anchors.horizontalCenter: parent.horizontalCenter
        text: qsTr("Start")
        flat: false
        onClicked: introductionMessageScene.startClicked()
      }
    }
  }
  //! [Scene 2]

  //! [Adding the game scene]
  Scene {
    id: gameScene
    visible: window.currentScene === Main.GameScene.Game

    readonly property int gridSize: 10
    readonly property int enemyCount: 5
    readonly property int boardSize: Math.min(width, height) - 4
    readonly property int cellSize: boardSize / gridSize

    property point playerPosition: Qt.point(0, 0)
    property list<point> naziPositions: []
    property int startTime: 0

    signal finished(score: int, time: int)

    Component.onCompleted: {
      // Generate a list of random office cubicles occupied by Nazis.
      while (naziPositions.length < enemyCount) {
        const x = Math.floor(Math.random() * gridSize)
        const y = Math.floor(Math.random() * gridSize)
        if (!naziPositions.some(e => e.x === x && e.y === y) && !(x === 0 && y === 0)) {
          naziPositions.push(Qt.point(x, y));
        }
      }
    }

    onVisibleChanged: {
      if (visible) {
        startTime = Date.now();
      }
      //! [Read Nazi positions in Blind mode]
      // Inform blind users of the enemy positions
      const boxes = naziPositions.map((pos) => (pos.y * gridSize) + pos.x + 1)
      const text = `There are Nazis in cells ${boxes.slice(0, -1).join(", ")} and ${boxes[boxes.length-1]}`;
      if (visible && window.blindMode && tts.state === TextToSpeech.Ready) {
        tts.say(text);
      }
      //! [Read Nazi positions in Blind mode]
      //! [Enable STT]
      if (visible && window.blindMode) {
        SpeechToText.startSpeechToText("en-US");
      }
      //! [Enable STT]
    }

    function move(direction: int) {
      if (horizontalAnimation.running || verticalAnimation.running) {
        return;
      }

      switch (direction) {
        case Main.MoveDirection.Up:
          if (playerPosition.y > 0) {
            playerPosition.y--;
            verticalAnimation.to = board.y + playerPosition.y * cellSize;
            verticalAnimation.start();
          }
          break;
        case Main.MoveDirection.Left:
          if (playerPosition.x > 0) {
            playerPosition.x--;
            horizontalAnimation.to = board.x + playerPosition.x * cellSize;
            horizontalAnimation.start();
          }
          break;
        case Main.MoveDirection.Down:
          if (playerPosition.y < gridSize-1) {
            playerPosition.y++;
            verticalAnimation.to = board.y + playerPosition.y * cellSize;
            verticalAnimation.start();
          }
          break;
        case Main.MoveDirection.Right:
          if (playerPosition.x < gridSize-1) {
            playerPosition.x++;
            horizontalAnimation.to = board.x + playerPosition.x * cellSize;
            horizontalAnimation.start();
          }
          break;
      }

      naziPositions.forEach((position, index) => {
        if (playerPosition.x === position.x && playerPosition.y === position.y) {
          naziPositions.splice(index, 1);
          if (window.blindMode && tts.state === TextToSpeech.Ready && naziPositions.length > 0) {
            tts.say(`You have sabotaged a Nazi! ${naziPositions.length + 1} coworkers remaining.`)
          }
        }
      });
      if (naziPositions.length === 0) {
        const totalTime = Date.now() - startTime;
        if (tts.state === TextToSpeech.Speaking) {
          tts.stop();
        }
        if (window.blindMode) {
          SpeechToText.stopSpeechToText();
        }
        gameScene.finished(enemyCount, totalTime);
      }
    }

    //! [Handle keyboard input]
    focus: visible
    Keys.forwardTo: controller

    TwoAxisController {
      id: controller
      inputActionsToKeyCode: {
        "up": Qt.Key_W,
        "down": Qt.Key_S,
        "left": Qt.Key_A,
        "right": Qt.Key_D
      }

      onInputActionReleased: (actionName) => {
        switch (actionName) {
          case "up":
            gameScene.move(Main.MoveDirection.Up);
            break;
          case "left":
            gameScene.move(Main.MoveDirection.Left);
            break;
          case "down":
            gameScene.move(Main.MoveDirection.Down);
            break;
          case "right":
            gameScene.move(Main.MoveDirection.Right);
            break;
        }
      }
    }
    //! [Handle keyboard input]

    Grid {
      id: board
      columns: gameScene.gridSize
      rows: gameScene.gridSize
      width: gameScene.boardSize
      height: gameScene.boardSize
      anchors.centerIn: parent
      //! [Hide the board from screen readers]
      Accessible.ignored: true
      //! [Hide the board from screen readers]

      Repeater {
        model: gameScene.gridSize * gameScene.gridSize
        Rectangle {
          property bool containsEnemy: {
            const x = index % gameScene.gridSize
            const y = Math.floor(index / gameScene.gridSize)
            return gameScene.naziPositions.some((nazi) => nazi.x === x && nazi.y === y)
          }

          width: gameScene.cellSize
          height: gameScene.cellSize
          border.color: Theme.appButton.backgroundColor
          color: window.highContrast ? "navy" : "transparent"

          MultiResolutionImage {
            // the correct image version is used, based on the GameWindow size
            property url origin: parent.containsEnemy ? Qt.resolvedUrl("../assets/img/Nazi.png") : ""

            width: parent.width - 4
            height: parent.height - 4
            anchors.centerIn: parent
            source: origin
          }
        }
      }
    }

    MultiResolutionImage {
      id: player
      source: Qt.resolvedUrl("../assets/img/Player.png")
      width: gameScene.cellSize - 4
      height: gameScene.cellSize - 4
      x: animatedX
      y: animatedY

      property real animatedX: board.x + gameScene.playerPosition.x * gameScene.cellSize
      property real animatedY: board.y + gameScene.playerPosition.y * gameScene.cellSize

      NumberAnimation on animatedX {
        id: horizontalAnimation
        duration: 200
      }
      NumberAnimation on animatedY {
        id: verticalAnimation
        duration: 200
      }
    }

    //! [Handle speech commands]
    Connections {
      target: SpeechToText

      function onSpeechToTextResult(result) {
        const commandRegex = /move ([A-Za-z]+)/i;
        if (!commandRegex.test(result)) {
          console.warn(`Unrecognized voice command: ${result}`);
          return;
        }
        const directionText = commandRegex.exec(result)[1];
        switch (directionText) {
          case "up":
            move(Main.MoveDirection.Up);
            break;
          case "left":
            move(Main.MoveDirection.Left);
            break;
          case "down":
            move(Main.MoveDirection.Down);
            break;
          case "right":
            move(Main.MoveDirection.Right);
            break;
        }
      }
    }
    //! [Handle speech commands]
  }
  //! [Adding the game scene]

  //! [Game over scene]
  Scene {
    id: gameOverScene
    visible: window.currentScene === Main.GameScene.GameOver

    readonly property string headerText: qsTr("Congratulations!")
    readonly property string scoreText: qsTr("You sabotaged %1 Nazis").arg(window.finalScore)

    Column {
      spacing: 0
      width: parent.width
      anchors.centerIn: parent

      AppText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: gameOverScene.headerText
        font.pixelSize: 36
      }

      AppText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: gameOverScene.scoreText
        font.pixelSize: 36
      }
    }
  }
  //! [Game over scene]

  //! [Connecting the different scenes]
  Connections {
    target: selectGameModeScene

    function onTraditionalModeSelected() {
      window.highContrast = false;
      window.blindMode = false;
      window.currentScene = Main.GameScene.IntroductionMessage;
    }
    function onHighContrastModeSelected() {
      window.highContrast = true;
      window.blindMode = false;
      window.currentScene = Main.GameScene.IntroductionMessage;
    }
    function onBlindModeSelected() {
      window.highContrast = false;
      window.blindMode = true;
      window.currentScene = Main.GameScene.IntroductionMessage;
    }
  }

  Connections {
    target: introductionMessageScene

    function onStartClicked() {
      window.currentScene = Main.GameScene.Game;
    }
  }

  Connections {
    target: gameScene
    function onFinished(score: int, time: int) {
      window.finalScore = score;
      window.currentScene = Main.GameScene.GameOver;
    }
  }
  //! [Connecting the different scenes]
}
