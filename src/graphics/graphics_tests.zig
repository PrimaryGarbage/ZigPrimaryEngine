const gr = @import("graphics.zig");

test "Load image from valid file" {
    const testImagePath = "./res/img/SayGex.jpg";
    var image = try gr.Image.loadFromFile(testImagePath, gr.Image.Format.jpeg);
    image.destroy();
}

test "Load image from invalid file" {
    const testImagePath = "./res/img/SayGexINVALID.jpg";
    var image = try gr.Image.loadFromFile(testImagePath, gr.Image.Format.jpeg);
    image.destroy();
}
