# Meow's Repo

To view the repo go [here](https://apt.xela.codes)!

This is a slightly modified version of [WilsontheWolf's Repo](https://github.com/WilsontheWolf/repo). Check it out for more information.

# Building

Building is handled by github actions. Just set your github pages settings to be deployed with GitHub Actions.

Afterwords continue onto [Setup the Repo](#setup-the-repo).

# Setup the Repo

There is a file called `config.json`.
This file has config values to modify your repo with.

Here is an example.

```json
{
  "name": "My Cool Repo",
  "base": "/",
  "url": "https://example.com/",
  "desc": "My repo."
}
```

The name is what shows up on your home page and in the package manager.

The base is the url where your files start, ending with a `/`. If you wanted to make your repo at https://example.com/repo your url is `/repo/`.

The url is the full url to your repo. This is used for package manager links and depiction URL's ending with a `/`.

The desc is used for metadata for your repo.

# Adding and Modifying Packages

To add/update packages first add the debian file to the `debs` folder.

Doing this automatically adds the deb to the repo on next build. However, this won't add data for the depictions. It will try to infer as much as it can from the package to make an ok depiction.

To add data to the depictions, make a folder with the name of the package id in the `info` folder.

Then make a file in that folder named `info.json`.

From here we can add values. Here is what a fully populated info looks like.

```json
{
  "name": "My Tweak",
  "tagline": "My cool tweak!",
  "desc": "This is my cool tweak. Its pretty cool!",
  "banner": {
    "text": "I am important read me!",
    "color": "red"
  },
  "screenshots": [
    {
      "name": "image.png",
      "accessibilityText": "Describe the image."
    }
  ],
  "changelog": [
    {
      "version": "0.0.2",
      "date": "March 10, 2022",
      "changes": "- The tweak is now 101% cooler."
    },
    {
      "version": "0.0.1",
      "date": "March 5, 2022",
      "changes": "- Initial Release"
    }
  ]
}
```

Please note that every field is optional and will attempt to either infer a value, use a placeholder value or not display at all.

The changelog should always have the newest version on top to prevent issues.

Images need to be placed in a folder called `screenshots` in the folder with the info.

The description and changes in the changelog support markdown.

Adding a file called `icon.png` in your tweak's info folder will add that icon to the tweak.

After this is all setup you can rebuild your repo. It will be built with all your new packages.
