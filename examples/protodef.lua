local protodef = {}

protodef.c2s = {
    package = {
        type = 0,
        session = 0,
    },
    handshake = {
        response = {
            msg = "",
        }
    },
    get = {
        request = {
            what = "",
        },
        response = {
            result = "",
        },
    },
    set = {
        request = {
            what = "",
            value = "",
        }
    },
}

protodef.s2c = {
    package = {
        type = 0,
        session = 0,
    },
    heartbeat = {1},
}

return protodef

