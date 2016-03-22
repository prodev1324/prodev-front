var utils = require('../utils');

var helper = module.exports;

helper.lookingForPeople = function() {
    return $$('.looking-for-people input').get(0);
};

helper.lookingForPeopleReason = function() {
    return $$('.looking-for-people-reason input').get(0);
};

helper.toggleIsLookingForPeople = function() {
    helper.lookingForPeople().click();
};

helper.editLogo = function() {
    let inputFile = $('#logo-field');

    var fileToUpload = utils.common.uploadImagePath();

    return utils.common.uploadFile(inputFile, fileToUpload);
};

helper.getLogoSrc = function() {
    return $('.image-container .image');
};

helper.requestOwnershipLb = function() {
    return $('div[tg-lb-request-ownership]');
};

helper.requestOwnership = function() {
    $('tg-admin-project-request-ownership .request').click();
};

helper.changeOwner = function() {
    $('tg-admin-project-change-owner .request').click();
};

helper.acceptRequestOwnership = function() {
    helper.requestOwnershipLb().$('.button-green').click();
};

helper.changeOwnerSuccessLb = function() {
    return $('.lightbox-generic-success');
};

helper.getChangeOwnerLb = function() {
    let el = $('div[tg-lb-change-owner]');

    let obj = {
        el: el,
        waitOpen: function() {
            return utils.lightbox.open(el);
        },
        waitClose: function() {
            return utils.lightbox.close(el);
        },
        search: function(q) {
            el.$$('input').get(0).sendKeys(q);
        },
        select: function(index) {
            el.$$('.user-list-single').get(index).click();
        },
        addComment: function(text) {
            el.$('.add-comment a').click();
            el.$('textarea').sendKeys(text);
        },
        send: function() {
            el.$('.submit-button').click();
        }
    };

    return obj;
};
