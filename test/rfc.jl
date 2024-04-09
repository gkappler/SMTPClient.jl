@test rfc5322mail("an@test.de", "test subject", "test body"; from = "sender@test.de", date = DateTime(2020,12,2)) == """
From: sender@test.de
To: an@test.de
Cc: 
Subject: test subject
MIME-Version: 1.0
Date: Wed, 2 Dec 2020 00:00:00 +0100
Content-Type: text/plain; charset="UTF-8"

test body
"""
    
@test rfc5322mail("an@test.de", "test subject", Markdown.MD("test *markdown*"); from = "sender@test.de", date = DateTime(2020,12,2)) == """
From: sender@test.de
To: an@test.de
Cc: 
Subject: test subject
MIME-Version: 1.0
Date: Wed, 2 Dec 2020 00:00:00 +0100
Content-Type: text/plain; charset="UTF-8"

test body
"""
    
