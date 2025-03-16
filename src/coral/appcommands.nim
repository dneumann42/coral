type
  CommandKind* = enum
    pushScene
    popScene
    gotoScene

  Command* = object
    case kind*: CommandKind
      of pushScene:
        pushId*: string
      of gotoScene:
        gotoId*: string
      else:
        discard
