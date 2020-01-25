// XM File loader - for MidiTrax

use "module.eh"
use "dataio.eh"
use "error.eh"
use "string.eh"

def Int.reverse_endian(): Int {
    ((this & 0xFF00) >> 8) + ((this & 0x00FF) << 8) }

def to_effect(x: Int): Int {
    switch (x) {
        0xD: 90
        0xEC: 60
        0xED: 30
        else: -1 } }

def to_arg(eff: Int, arg: Int): Int = arg

def Module.load_xm(path: String) {
    var f = fopen_r(path)
    var twentybytes = new [Byte](20)
    var seventeenbytes = new [Byte](17)
    f.readarray(seventeenbytes, 0, 17)
    if (ba2utf(seventeenbytes) != "Extended Module: ") error(ERR_IO, "File is either corrupted or is not an XM module")
    f.readarray(twentybytes, 0, 20)
    this.title = ba2utf(twentybytes).trim()
    if (f.readubyte() != 0x1A) error(FAIL, "File is either corrupted or is not an XM module")
    f.readarray(twentybytes, 0, 20)
    this.comments = "Original file by " + ba2utf(twentybytes).trim()
    f.skip(6)
    var order_num = f.readushort().reverse_endian()
    f.skip(2)
    this.channels = f.readushort().reverse_endian()
    var pattern_num = f.readushort().reverse_endian()
    f.skip(6)
    // tempo in XM is different than tempo in MidiTrax
    // tempo in MidiTrax is BPM in XM
    this.tempo = f.readushort().reverse_endian()
    var order_array = new [Byte](256)
    f.readarray(order_array, 0, 256)
    for (var i=0, i<order_num, i+=1) this.orderlist.add(order_array[i])
    var pat: Pattern
    var p: Int // part
    var s: Int // step
    var c: Int // channel
    var row_num: Int
    var data_size: Int
    var data_counter: Int
    var note: Bool
    var inst: Bool
    var vol: Bool
    var eff: Bool
    var arg: Bool
    var temp = new [Int](5)
    for (var i=0, i<pattern_num, i+=1) {
        p = 0; s = 0; c = 0; data_counter = 0
        pat = new Pattern(i.tostr(), this.channels)
        f.skip(5) // header size
        row_num = f.readushort().reverse_endian()
        data_size = f.readushort().reverse_endian()
        while (data_counter < data_size) {
            note = true inst = true vol = true eff = true arg = true
            temp[0] = f.readubyte()
            data_counter += 1
            if (temp[0] < 0x80) {
                pat.set(c, s, PAT_NOTE, if (temp[0] == 97) 200 else temp[0] + 11)
                f.skip(1)
                pat.set(c, s, PAT_VOLUME, f.readubyte()*1.984375)
                temp[3] = f.readubyte()
                temp[4] = f.readubyte()
/*              pat.set(c, s, PAT_EFFECT1, to_effect(temp[3]))
                pat.set(c, s, PAT_ARG1, to_arg(temp[3], temp[4])) */
                data_counter += 4 }
            else {
                if ((temp[0] & 1) > 0) {
                    temp[1] = f.readubyte()
                    if (temp[1] == 97) pat.set(c, s, PAT_NOTE, 200) else pat.set(c, s, PAT_NOTE, temp[1] + 11)
                    data_counter += 1 }
                if ((temp[0] & 2) > 0) {
                    f.skip(1)
                    data_counter += 1 }
                temp[2] = 0
                if ((temp[0] & 4) > 0) {
                    temp[2] = f.readubyte().cast(Float) * 1.984375
                    if ((temp[0] & 1) == 0)
                        pat.set(c, s, PAT_NOTE, temp[1] - 1)
                    pat.set(c, s, PAT_VOLUME, temp[2])
                    data_counter += 1 }
                if ((temp[0] & 8) > 0) {
                    temp[3] = f.readubyte()
                    pat.set(c, s, PAT_EFFECT1, to_effect(temp[3]))
                    data_counter += 1 }
                if ((temp[0] & 16) > 0) {
                    f.skip(1)
                    data_counter += 1 }
                if ((temp[0] & 1) > 0 && temp[2] == 0) pat.set(c, s, PAT_VOLUME, 127) }
            c += 1
            if (c >= this.channels) {
                c = 0
                s += 1 } }
        this.patterns.add(pat) }
    f.close()
    this.steps = row_num }