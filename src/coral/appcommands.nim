import messages

type
  CommandKind* = enum
    pushScene
    popScene
    gotoScene
    emit

  Command* = object
    case kind*: CommandKind
      of pushScene:
        pushId*: string
      of gotoScene:
        gotoId*: string
      of emit:
        msg*: AbstractMessage
      else:
        discard
