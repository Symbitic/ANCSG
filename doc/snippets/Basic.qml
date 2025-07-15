// Copyright Felgo

//! [first_code]
import Felgo
import QtQuick
import QtTextToSpeech
import "."

GameWindow {
  id: window
  screenHeight: 960
  screenWidth: 640

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
}
//! [first_code]
