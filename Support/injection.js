let headings = Array.from(document.querySelectorAll('h1, h2, h3, h4, h5, h6'))

// generate id for all headings if there isn't one already
headings.forEach( (heading, index) => {
	if (!heading.id) {
		let parts = heading.textContent.trim().split(' ').concat([index])
		heading.id = parts.join('_')
	}
})

// create observer
let observer = new IntersectionObserver(function(entries) {
	for (index in entries) {
		let entry = entries[index]
		if (entry.isIntersecting === false && entry.boundingClientRect.top <= entry.rootBounds.top) {
			window.webkit.messageHandlers.headingVisible.postMessage({id: entry.target.id})
			return
		} else if (
			entry.isIntersecting === false &&
			entry.boundingClientRect.bottom > entry.rootBounds.bottom
		) {
			let index = headings.findIndex(element => element.id == entry.target.id )
			let previousHeading = headings[index - 1]
			window.webkit.messageHandlers.headingVisible.postMessage({id: previousHeading.id})
			console.log(previousHeading)
			return
		}
	}
}, { rootMargin: '-50px 0 -35% 0', threshold: 1.0 });

// register scroll view to handle heading on top of the page
window.onscroll = function() {
    if (document.documentElement.scrollTop <= 0) {
        const handler = window.webkit.messageHandlers.headingVisible
        if (handler !== undefined) {
            handler.postMessage({id: headings[0].id})
        }
    }
}

// expand all detail tags
function expandAllDetailTags() {
	document.querySelectorAll('details').forEach( detail => detail.setAttribute('open', true) )	
}

// convert all headings into objects and send it to app side
function getOutlineItems() {
	window.webkit.messageHandlers.headings.postMessage(
		headings.map( heading => {
			return {
				id: heading.id,
				text: heading.textContent.trim(),
				tag: heading.tagName,
			}
		})
	)
}

// observe headings for intersection
function observeHeadings() {
	observer.disconnect()
	headings.forEach( heading => { observer.observe(heading) })
}

function scrollToHeading(id) {
	element = document.getElementById(id)
	element.scrollIntoView({block: 'start', inline: 'start', behavior: 'smooth'})
}
