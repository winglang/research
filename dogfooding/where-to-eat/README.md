# Where to Eat?

Hungry dogs need their food! Shows a website with restaurants around you. Allows you to bookmark your favorite restaurants

## Team

@ainvoner, @staycoolcall911

## Demo Video

[YouTube](https://www.youtube.com/watch?v=ADD_VIDEO)


## Issues

- [#1289](https://github.com/winglang/wing/issues/1289) - Schedule for sim
- [#1919](https://github.com/winglang/wing/issues/1919) - .tfaws folder disappears?
- [#1293](https://github.com/winglang/wing/issues/1293) - cloud.Website - Simulator implementation
- [#2081](https://github.com/winglang/wing/issues/2081) - Test fails when using external js file
- [#1966](https://github.com/winglang/wing/issues/1966) - Reference to this is unknown inside cloud.Api method definition
- [#1961](https://github.com/winglang/wing/issues/1961) - Cannot reference interfaces instances from an inflight context
- [#1832](https://github.com/winglang/wing/issues/1832) - adding bucket.public_url() to the wing console
- [#2133](https://github.com/winglang/wing/issues/2133) - :new: Unsuccessful compilation creates an empty main.wsim.######.tmp folder
- [#2138](https://github.com/winglang/wing/issues/2138) - :new: Bucket.add_file()




open issue: console download file - download is partial

open issue: support cors - both on website (done) and on the api
open issue:
        log("new resutrant id: ${id_str}");
        let j = Json { 
          name: resturant.name, 
          type: resturant.type,
          distance: resturant.distance
        };
        log("adding new resturatn ${id_str} with data: $str.from_json{j}");
        return this._add(id_str, j);
    strange error

open issue: if struct definition doesn't have a semicolon the error is not clear
open issue: api resource content is not cleared after reloading the simulator

open issue: this is an error:
    let body: Json = req.body ?? {name: “”, type: “”, rating: 0};
    Expected type to be "str", but got "num" instead

Keep getting:
tf plugin invalid: had to recompile
food.tfaws git:(where-to-eat) ✗ terraform apply
╷
│ Error: Unrecognized remote plugin message: 
│ 
│ This usually means that the plugin is either invalid or simply
│ needs to be recompiled to support the latest protocol.
│ 
│ 
╵


open issue: need to invalidate cloudfront
open issue: website files on s3 are not updating









